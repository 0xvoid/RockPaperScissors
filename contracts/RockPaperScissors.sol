pragma solidity ^0.4.8;

import "./Owned.sol";

contract RockPaperScissors is Owned {
    
    enum moveResultStates { Default, Started, Playing, Won, Tied, Terminated }
    enum moveState {Default, Rock, Paper, Scissor}
    
    struct GameStruct {
        address firstPlayer;
        uint firstStake;
        uint firstPlayerMove;
        bytes32 firstMoveSecretHash;
        uint  firstMoveSecret;
        
        address secondPlayer;
        uint secondStake;
        uint secondPlayerMove;
        bytes32 secondMoveSecretHash;
        uint secondMoveSecret;
        
        uint expiryBlock;
        moveResultStates moveResult;
        uint    moveNonce;
    }
    
    mapping (bytes32 => GameStruct) gameStore;
    
    function RockPaperScissors () 
        public
    {
        owner = msg.sender;
    }
    
    function startGame() 
        public
        payable
        onlyWhenLive
        returns (bytes32 gameId)
    {
        require(msg.value > ownerCut);
        
        uint stake = (msg.value - ownerCut);
        ownerBank += ownerCut; //pay self
        LogCommisionPayed(ownerCut);
        
        //Create Game
        GameStruct memory newGame = GameStruct({
            firstPlayer : msg.sender,
            firstStake : stake,
            firstPlayerMove : 0,
            firstMoveHash : '',
            secondPlayer : address(0), 
            secondStake : 0, 
            secondPlayerMove : 0,
            secondMoveHash: '',
            expiryBlock : block.number + gameDuration,
            moveResult: moveResultStates.Started,
            moveNonce : 1
        });
        bytes32 newGameId = keccak256(msg.sender, gameNonce++);
        gameStore[newGameId] = newGame;
        
        LogGameStarted(newGameId,  msg.sender, block.number + gameDuration);
        LogPlayerJoinedGame(newGameId,  msg.sender, stake );
        return newGameId;
    }
    
    
    function joinGame(bytes32 gameId)
        public 
        onlyWhenLive
        payable
        returns (bool success)
    {
        //here move is a hashed value, using a secret given to the player offline. The construction of which is yet to be relised/written/still getting figured out :)
        require(gameStore[gameId].moveResult == moveResultStates.Started);
        require(gameStore[gameId].expiryBlock < block.number);  //game has not expired
        require(gameStore[gameId].firstPlayer != msg.sender);   //first player shouldn't join its own game
        
        uint stake2 = (msg.value - ownerCut);
        require(stake2 >= gameStore[gameId].firstStake);     //second player can't lowball the stake price
        
       
        ownerBank += ownerCut; //pay self
        LogCommisionPayed(ownerCut);
        
        gameStore[gameId].secondPlayer = msg.sender;
        gameStore[gameId].secondStake = stake2;
        gameStore[gameId].moveResult = moveResultStates.Playing;
        
        
        LogPlayerJoinedGame(gameId, msg.sender, stake2 );
        getGameResult(gameId);
        
        return true;
    }
    
    function submitMove(bytes32 gameId, uint move, bytes32 hashedSecret)
        public 
        onlyWhenLive
        returns(bool success)
    {
        require(gameStore[gameId].moveResult == moveResultStates.Playing);
        require(gameStore[gameId].expiryBlock < block.number);   //game has not expired
        
        if ( msg.sender == gameStore[gameId].firstPlayer ){           // require();
            gameStore[gameId].firstPlayerMove = move;
            gameStore[gameId].firstMoveHash = hashedSecret;
        }
        else if(msg.sender == gameStore[gameId].secondPlayer) {
            gameStore[gameId].secondPlayerMove = move;
            gameStore[gameId].secondMoveHash = hashedSecret;
        }
        else 
            revert(); //only the 2 addresses can make moves
        
        LogPlayerSubmittedMove(gameId, msg.sender, move, hashedSecret);
        return true;
    }
    
    function revealMove(bytes32 gameId, uint secret)
        public 
        onlyWhenLive
        returns (bool success)
    {
        require(gameStore[gameId].moveResult == moveResultStates.Playing);
        require(gameStore[gameId].expiryBlock < block.number);   //game has not expired
         
        if(msg.sender == gameStore[gameId].firstPlayer) { 
            require(gameStore[gameId].firstMoveSecret == 0);
            gameStore[gameId].firstMoveSecret = secret;
            LogPlayerRevealedMove( gameId, msg.sender, secret);
            if (gameStore[gameId].secondMoveSecret != 0){ getGameResult(gameId);}
        }
        else if (msg.sender == gameStore[gameId].secondPlayer){ 
            require(gameStore[gameId].secondMoveSecret == 0);
            gameStore[gameId].secondMoveSecret = secret;
            LogPlayerRevealedMove( gameId, msg.sender, secret);
            if (gameStore[gameId].firstMoveSecret != 0){getGameResult(gameId);}
        }
        else { revert(); } 
        
        return true;
    }
    
    function terminateGame(bytes32 gameId)
        public 
        onlyWhenLive
        returns (bool success)
    {
        //game is not termiated,Won already
        require(gameStore[gameId].moveResult != moveResultStates.Won);
        require(gameStore[gameId].moveResult != moveResultStates.Terminated);
        
        //must be only the two players
        if(msg.sender == gameStore[gameId].firstPlayer) { }
        else if (msg.sender == gameStore[gameId].secondPlayer){ }
        else { revert(); }
        
        gameStore[gameId].moveResult = moveResultStates.Terminated;
        LogGameTerminated(gameId, msg.sender, gameStore[gameId].firstStake, gameStore[gameId].secondStake);
        
        return true;
    }
    
     function withdraw(bytes32 gameId)
        public 
        onlyWhenLive
        returns (bool success)
    {
        require(gameStore[gameId].moveResult != moveResultStates.Tied);
        require(gameStore[gameId].moveResult != moveResultStates.Playing);
        //Only the two players
        if(msg.sender == gameStore[gameId].firstPlayer) {
            //revert if player has lost game
            require(gameStore[gameId].firstStake != 0);         
            gameStore[gameId].firstPlayer.transfer(gameStore[gameId].firstStake);
            //LogPlayerWithdrwal()
        }
        else if (msg.sender == gameStore[gameId].secondPlayer){
            require(gameStore[gameId].secondStake != 0);
            gameStore[gameId].firstPlayer.transfer(gameStore[gameId].firstStake);
            //LogPlayerWithdrwal()
        }
        else { revert(); }
        
        
        return true;
    }
    
    function generateMove(uint secret, moveState move)
        public
        pure
        onlyWhenLive
    {
        //split 
    }
    
    //------------------------------
    //private methods
    
    function gameOver(bytes32 gameId, address winner)
        private
    {
         if(winner == gameStore[gameId].firstPlayer) {
            gameStore[gameId].firstStake +=  gameStore[gameId].secondStake;
            gameStore[gameId].secondStake = 0;
         }
         else if (winner == gameStore[gameId].secondPlayer) {
            gameStore[gameId].secondStake +=  gameStore[gameId].firstStake;
            gameStore[gameId].firstStake = 0;
         }
         gameStore[gameId].moveResult = moveResultStates.Won;
    }
    
    function getGameResult(bytes32 gameId)
        private
    {
        //TODO: interpret move string as one of {rock, paper, scissor}
        
        //if move1 == move 2, set status = Tied 
        //Tied matrix   (S,S), (R,R), (P,P)
        gameStore[gameId].moveResult = moveResultStates.Tied;
        gameStore[gameId].firstPlayerMove = '';
        gameStore[gameId].secondPlayerMove = '';
        
        // Result matrix (1, 2, Winner)
        //(S,P,1), (S,R,2), (R,S,1) , (R,P,2), (P,R,1), (P,S,1)
        
        // TODO: Detrmine Win / Tie. Set storage values accordingly.
    }
    
     function KillMe()
        public
        onlyOwner
    {
        require(isStopped);
        selfdestruct(owner);
    }
    
    function () public {revert();} 
}
