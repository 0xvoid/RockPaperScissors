pragma solidity ^0.4.8;

contract RockPaperScissors {
    
    address public owner;
    uint    public ownerBank;
    bool    public isStopped;
    uint    public gameNonce;
    uint    public gameDuration = 0; // for now
    uint    public ownerCut = 0; // for now
    
     
    modifier onlyOwner {
         require (msg.sender == owner);
         _;
    }

    modifier onlyWhenLive {
        require (isStopped);
        _;
    }
    
    struct gameStruct {
        address firstPlayer;
        address secondPlayer;
        uint firstStake;
        uint secondStake;
        uint expiryBlock;
    }
    
    enum  moveResultStates { Default, Playing, Won, Tied, Terminated }
    struct moveStruct {
        bytes32 firstPlayerMove;
        bytes32 secondPlayerMove;
        moveResultStates moveResult;
    }
    
    
    //move result states = playing, Won , lost, tied
    
    mapping (bytes32 => gameStruct) gameStore;
    mapping (bytes32 => moveStruct) moveStore;
    
    event LogContractStateChanged   (bool contractState);
    event LogGameStarted            (bytes32 indexed gameId, address indexed firstPlayer, uint firstStake);
    event LogSecondPlayerJoinedGame (bytes32 indexed gameId, address indexed secondPlayer,  uint secondStake );
    event LogGameTerminated         (bytes32 indexed gameId, address indexed terminator, uint firstStake, uint secondStake);
    event LogOwnerWithdrwal         (uint withdrawAmount);
    
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
        gameStruct memory newGame = gameStruct({ firstPlayer : msg.sender, secondPlayer : address(0), firstStake : (msg.value - ownerCut), secondStake : 0, expiryBlock : block.number + gameDuration});
        ownerBank += ownerCut; //pay self
        bytes32 newGameId = keccak256(msg.sender, gameNonce++);
        gameStore[newGameId] = newGame;
        
        //Create & save first Move
        moveStruct memory newMove = moveStruct({ 
            firstPlayerMove : firstMove,
            secondPlayerMove : '',
            moveResult: moveResultStates.Playing
        });
        moveStore[newGameId] = newMove;
        
        return newGameId;
    }
    
    
    function joinAndMakeMove(bytes32 gameId, bytes32 move)
        public 
        onlyWhenLive
        payable
        returns (bool success)
    {
        require(moveStore[gameId].moveResult == moveResultStates.Playing);
        require(gameStore[gameId].expiryBlock < block.number);  //game has not expired
        require(gameStore[gameId].firstPlayer != msg.sender);   //first player shouldn't join its own game
        require(msg.value > ownerCut);
        
        gameStore[gameId].secondStake = (msg.value - ownerCut);
        ownerBank += ownerCut; //pay self
        moveStore[gameId].secondPlayerMove = move;
        
        LogSecondPlayerJoinedGame(gameId, gameStore[gameId].secondPlayer, gameStore[gameId].secondStake );
        
        getGameResult(gameId);
        
        return true;
    }
    
    function makeMove(bytes32 gameId, bytes32 move)
        public
        onlyWhenLive
        payable
        returns (bool success)
    {
        require(moveStore[gameId].moveResult != moveResultStates.Won);
        require(moveStore[gameId].moveResult != moveResultStates.Terminated);
        require(gameStore[gameId].expiryBlock < block.number);   //game has not expired
        require(gameStore[gameId].firstStake  != 0); 
        require(gameStore[gameId].secondStake != 0); 
        
        if(msg.sender == gameStore[gameId].secondPlayer) 
            moveStore[gameId].secondPlayerMove = move;
        else if ( msg.sender == gameStore[gameId].firstPlayer)
            moveStore[gameId].firstPlayerMove = move;
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
        require(moveStore[gameId].moveResult != moveResultStates.Won);
        require(moveStore[gameId].moveResult != moveResultStates.Terminated);
        
        //must be only the two players
        if(msg.sender == gameStore[gameId].firstPlayer) { }
        else if (msg.sender == gameStore[gameId].firstPlayer){ }
        else { revert(); }
        
        moveStore[gameId].moveResult = moveResultStates.Terminated;
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
        else if (msg.sender == gameStore[gameId].firstPlayer){
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
         else if (winner == gameStore[gameId].firstPlayer) {
            gameStore[gameId].secondStake +=  gameStore[gameId].firstStake;
            gameStore[gameId].firstStake = 0;
         }
         moveStore[gameId].moveResult = moveResultStates.Won;
    }
    
    function getGameResult(bytes32 gameId)
        private
    {
        //interpret moveStore
        
        //if move1 == move 2, set status = Tied 
        //Tied matrix   (S,S), (R,R), (P,P)
        moveStore[gameId].moveResult = moveResultStates.Tied;
        
        // Result matrix (1, 2, Winner)
        //(S,P,1), (S,R,2), (R,S,1) , (R,P,2), (P,R,1), (P,S,1)
        //
    }
    
   
    
    //-----------------------------------------------------------------------
    //Owner functions
    
    function setContractState(bool _onOff)
        public 
        onlyOwner
        returns (bool stateValue)
    {
        LogContractStateChanged(_onOff);
        return isStopped = _onOff;
    }
    
    function ownerWithdrawal(uint _withdrawAmount) 
        public 
        onlyOwner
        onlyWhenLive
        returns (bool success)
    {
        require(ownerBank >= _withdrawAmount);
        require(ownerBank != 0 );
        ownerBank -= _withdrawAmount;
        msg.sender.transfer(_withdrawAmount);
        
        LogOwnerWithdrwal(_withdrawAmount);
        return true;
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
