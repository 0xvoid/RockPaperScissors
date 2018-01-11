pragma solidity ^0.4.8;

import "./Owned.sol";

contract RockPaperScissors is Owned {
    
    enum  moveResultStates { Default, Playing, Won, Tied, Terminated }
    
    struct GameStruct {
        address firstPlayer;
        address secondPlayer;
        uint firstStake;
        uint secondStake;
        uint expiryBlock;
        bytes32 firstPlayerMove;
        bytes32 secondPlayerMove;
        moveResultStates moveResult;
        uint    moveNonce;
    }
    
    mapping (bytes32 => GameStruct) gameStore;
    
    function RockPaperScissors () 
        public
    {
        owner = msg.sender;
    }
    
    function startGame(bytes32 firstMove) 
        public
        payable
        onlyWhenLive
        returns (bytes32 gameId)
    {
        require(msg.value > ownerCut);
        
        //Create Game
        GameStruct memory newGame = GameStruct({
            firstPlayer : msg.sender,
            secondPlayer : address(0), 
            firstStake : (msg.value - ownerCut),
            secondStake : 0, 
            expiryBlock : block.number + gameDuration,
            firstPlayerMove : firstMove,
            secondPlayerMove : '',
            moveResult: moveResultStates.Playing,
            moveNonce : 1
        });
        
        ownerBank += ownerCut; //pay self
        LogCommisionPayed(ownerCut);
        bytes32 newGameId = keccak256(msg.sender, gameNonce++);
        gameStore[newGameId] = newGame;
        
        return newGameId;
    }
    
    
    function joinAndMakeMove(bytes32 gameId, bytes32 move)
        public 
        onlyWhenLive
        payable
        returns (bool success)
    {
        //here move is a hashed value, using a secret given to the player offline. The construction of which is yet to be relised/written/still getting figured out :)
        require(gameStore[gameId].moveResult == moveResultStates.Playing);
        require(gameStore[gameId].expiryBlock < block.number);  //game has not expired
        require(gameStore[gameId].firstPlayer != msg.sender);   //first player shouldn't join its own game
        require(msg.value >= gameStore[gameId].firstStake);     //second palyer can't lowball the stake price
        
        gameStore[gameId].secondStake = (msg.value - ownerCut);
        ownerBank += ownerCut; //pay self
        LogCommisionPayed(ownerCut);
        gameStore[gameId].secondPlayerMove = move;
        
        LogSecondPlayerJoinedGame(gameId, gameStore[gameId].secondPlayer, gameStore[gameId].secondStake );
        
        getGameResult(gameId);
        
        return true;
    }
    
    function makeMove(bytes32 gameId, bytes32 move)
        public
        onlyWhenLive
        returns (bool success)
    {
        //here move is a hashed value, using a secret given to the player offline. The construction of which is yet to be relised/written/still getting figured out :)
        require(gameStore[gameId].moveResult != moveResultStates.Won);
        require(gameStore[gameId].moveResult != moveResultStates.Terminated);
        require(gameStore[gameId].expiryBlock < block.number);   //game has not expired
        require(gameStore[gameId].firstStake  != 0); 
        require(gameStore[gameId].secondStake != 0); 
        
        if ( msg.sender == gameStore[gameId].firstPlayer)
           // require();
            gameStore[gameId].firstPlayerMove = move;
        else if(msg.sender == gameStore[gameId].secondPlayer) 
            gameStore[gameId].secondPlayerMove = move;
        else 
            revert(); //only the 2 addresses can make moves
        
        
        getGameResult(gameId);
        
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
    
    function () public {revert();} 
}
