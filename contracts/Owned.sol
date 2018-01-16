pragma solidity ^0.4.8;

contract Owned {
 
    address public owner;
    uint    public ownerBank;
    bool    public isStopped;
    uint    public gameNonce;
    uint    public gameDuration = 10000; // for now
    uint    public ownerCut = 0; // for now
    
     modifier onlyOwner {
         require (msg.sender == owner);
         _;
    }

    modifier onlyWhenLive {
        require (isStopped);
        _;
    }
    
    event LogGameStarted            (bytes32 indexed gameId, address indexed player, uint expiryBlock);
    event LogPlayerJoinedGame       (bytes32 indexed gameId, address indexed player,  uint stake );
    event LogPlayerSubmittedMove    (bytes32 indexed gameId, address indexed player, uint move, bytes32 hashedSecret);
    event LogPlayerRevealedMove     (bytes32 indexed gameId, address indexed player, uint secret);
    event LogGameTerminated         (bytes32 indexed gameId, address indexed terminator, uint firstStake, uint secondStake);
   
    event LogOwnerWithdrwal         (uint withdrawAmount);
    event LogCommisionPayed         (uint payedAmount);
    event LogContractStateChanged   (bool contractState);
    
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
    
}
