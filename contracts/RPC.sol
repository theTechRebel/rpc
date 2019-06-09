pragma solidity ^0.5.0;

import 'openzeppelin-solidity/contracts/math/SafeMath.sol';
import 'openzeppelin-solidity/contracts/ownership/Ownable.sol';
import 'openzeppelin-solidity/contracts/lifecycle/Pausable.sol';

contract RPC is Ownable, Pausable{
    using SafeMath for uint;

    event LogContractDeath(address indexed sender);
    event LogSetAmount(address indexed sender, uint indexed amount);
    event LogSetMinDeadline(address indexed sender, uint indexed minDeadline);
    event LogEnrollPlayer1(address indexed player1,address indexed player2,
    bytes32 hashedMove,uint deadline,uint game, uint indexed amount);
    event LogEnrollPlayer2(address indexed player2,address indexed player1,
    uint move,uint game, uint indexed amount);
    event LogWinner(uint game,address indexed winner, address indexed loser,uint indexed amount);
    event LogDraw(uint indexed game,address indexed player1,uint amountToPlayer1,
     address indexed player2,uint amountToPlayer2);
     event LogQuit(uint indexed game,address indexed player1,uint amountToPlayer1,
     address indexed player2,uint amountToPlayer2);
     event LogWithdrawal(address indexed withdrawer, uint indexed amount);

    struct Game{
        address player1;
        address player2;
        uint amount1;
        uint amount2;
        bytes32 hashedMove;
        uint move;
        uint deadline;
    }
    enum moves {noMove,rock,paper,scissors}
    mapping(uint=>Game)  private games;
    mapping(address=>uint) private winnings;
    uint public amount;
    uint public gameCount;
    uint public minDeadline;
    bool private killed;

    constructor(uint _amount, uint _minDeadline) public{
        minDeadline = _minDeadline;
        amount = _amount;
    }
    modifier ifAlive(){
                require(!killed,"Contract is dead");
                _;
    }
    modifier  validateGameCount(uint _gameCount) {
        require(_gameCount>0,"Supply a valid game number");
        require(_gameCount<=gameCount,"This game has not been played yet");
        _;
    }
    function getHash(bytes32 secret,uint move,address player)public view returns(bytes32 hash){
        require(secret!=0,"provide a valid secret");
        require(move>0 && move<4,"Submit a move between 1 and 3");
        require(player!=address(0),"Provide a valid address");
        hash = keccak256(abi.encode(secret,move,player,address(this)));
    }
    function whoWon(uint p1,uint p2) public pure returns (uint){
        if(p1==p2){
            return 0;
        }else if((p1.mod(3)) == (p2.sub(1))){
            return 2;
        }else{
            return 1;
        }
    }
    function killContract() public whenPaused onlyOwner{
        killed = true;
        emit LogContractDeath(msg.sender);
    }
    function setAmount(uint _amount) public onlyOwner{
        amount = _amount;
        emit LogSetAmount(msg.sender,_amount);
    }
    function setMinDeadline(uint _minDeadline) public onlyOwner{
        minDeadline = _minDeadline;
        emit LogSetMinDeadline(msg.sender,_minDeadline);
    }
    function enrollPlayer1(uint _deadline,bytes32 _hashedMove,address _opponent)
    public payable whenNotPaused ifAlive returns(uint _gameCount){
        require(msg.value==amount,"Deposit the right amount to play");
        require(_hashedMove != 0, "Submit a valid move");
        require(_opponent != address(0), "Submit a valid opponent");
        require(_deadline >= minDeadline,"Deadline must be more than min deadline");
        _gameCount = gameCount++;
        emit LogEnrollPlayer1(msg.sender,_opponent,_hashedMove,_deadline,_gameCount,msg.value);
        Game memory _game = games[_gameCount];
        _game.player1 = msg.sender;
        _game.amount1.add(msg.value);
        _game.hashedMove = _hashedMove;
        _game.player2 = _opponent;
        _game.deadline = block.number.add(_deadline);
        games[_gameCount] = _game;
    }
    function enrollPlayer2(uint _gameCount, uint _move)
    public payable whenNotPaused ifAlive validateGameCount(_gameCount){
        require(msg.value==amount,"Deposit the right amount to play");
        require(_move>0 && _move<4,"Submit a move between 1 and 3");
        Game memory _game = games[_gameCount];
        require(_game.player1 != address(0),"You can not join a finished game");
        require(_game.player2 == msg.sender,"You are not allowed to play this game");
        emit LogEnrollPlayer2(msg.sender,_game.player1,_move,_gameCount,msg.value);
        _game.amount2.add(msg.value);
        _game.move = _move;
        games[_gameCount] = _game;
    }
    function determineWinner(uint _gameCount,uint _move,bytes32 _secret)
    public whenNotPaused ifAlive validateGameCount(_gameCount){
        require(_secret!=0,"provide a valid secret");
        require(_move>0 && _move<4,"Submit a move between 1 and 3");
        Game memory _game = games[_gameCount];
        require(_game.player1==msg.sender || _game.player2==msg.sender,
        "You are not either of the players of this game");
        require(_game.move>0,"Player 2 has not played yet");
        require(_game.hashedMove == getHash(_secret,_move,msg.sender),"Wrong secret or move submitted");
        uint _winnings = _game.amount1.add(_game.amount2);
        uint winner = whoWon(_move,_game.move);
        if(winner == 1){
            winnings[_game.player1].add(_winnings);
            emit LogWinner(_gameCount,_game.player1,
            _game.player2,_winnings);
        }else if(winner == 2){
            winnings[_game.player2].add(_winnings);
            emit LogWinner(_gameCount,_game.player2,
            _game.player1,_winnings);
        }else{
             winnings[_game.player1].add(_game.amount1);
             winnings[_game.player2].add(_game.amount2);
             emit LogDraw(_gameCount,_game.player1,_game.amount1,
            _game.player2,_game.amount2);
        }
        _game.amount1 = 0;
        _game.amount2 = 0;
        _game.player1 = address(0);
        _game.player2 = address(0);
        _game.move = 0;
        _game.hashedMove = 0;
        _game.deadline = 0;
        games[_gameCount] = _game;
    }
    function quit(uint _gameCount)
    public whenNotPaused ifAlive validateGameCount(_gameCount){
        Game memory _game = games[_gameCount];
        require(_game.deadline>block.number,"Deadline for quit has not been reached");
        require(_game.player1==msg.sender || _game.player2==msg.sender,
        "You are not either of the players of this game");
        winnings[_game.player1].add(_game.amount1);
        winnings[_game.player2].add(_game.amount2);
        emit LogQuit(_gameCount,_game.player1,_game.amount1,
            _game.player2,_game.amount2);
        _game.amount1 = 0;
        _game.amount2 = 0;
        _game.player1 = address(0);
        _game.player2 = address(0);
        _game.move = 0;
        _game.hashedMove = 0;
        _game.deadline = 0;
        games[_gameCount] = _game;
    }
    function withdraw(uint _gameCount)
    public whenNotPaused ifAlive validateGameCount(_gameCount){
        uint _amount = winnings[msg.sender];
        require(_amount>0,"You have no winnings");
        emit LogWithdrawal(msg.sender,_amount);
        winnings[msg.sender] = 0;
        msg.sender.transfer(_amount);
    }
}