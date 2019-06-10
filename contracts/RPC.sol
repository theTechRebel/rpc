pragma solidity ^0.5.0;

import 'openzeppelin-solidity/contracts/math/SafeMath.sol';
import 'openzeppelin-solidity/contracts/ownership/Ownable.sol';
import 'openzeppelin-solidity/contracts/lifecycle/Pausable.sol';

contract RPC is Ownable, Pausable{
    using SafeMath for uint;

    event LogContractDeath(address indexed sender);
    event LogSetAmount(address indexed sender, uint indexed amount);
    event LogSetMinDeadline(address indexed sender, uint indexed minDeadline);
    event LogEnrollPlayer1(address indexed player1,
    address indexed player2,bytes32 hashedMove,uint deadline,uint indexed amount);
    event LogEnrollPlayer2(address indexed player2,address indexed player1,
    uint plainMove,bytes32 hashedMove, uint indexed amount);
    event LogWinner(bytes32 hashedMove,address indexed winner, address indexed loser,uint indexed amount);
    event LogDraw(bytes32 indexed hashedMove,address indexed player1,uint amountToPlayer1,
     address indexed player2,uint amountToPlayer2);
     event LogQuit(bytes32 indexed hashedMove,address indexed player1,uint amountToPlayer1,
     address indexed player2,uint amountToPlayer2);
     event LogWithdrawal(address indexed withdrawer, uint indexed amount);

    struct Game{
        address player1; //player 1 address
        address player2; //player 2 address
        uint betAmount; //amount deposited by player 1 & player 2
        bytes32 P1HashedMove; //hashed move for player 1 so that player 2 does not know what it was
        uint P2PlainMove; //plain move for player 2 no need to hash because its the last move of the game
        uint GameDeadline; //deadline time for game to expire
    }
    enum moves {noMove,rock,paper,scissors} //options to play are rock, paper & scissors. O is NoMove
    mapping(bytes32=>Game)  private games; //holds the games plaid using P1 hash move
    mapping(address=>uint) private winnings; //holds player winnings
    uint public gameAmount; //amount required to play the game, to be deposited by each player
    uint public minGameDeadline; //holds the minimum time required to be set as deadline
    bool private killed; //determine if contract is killed

    constructor(uint _amount, uint _minDeadline) public{
        minGameDeadline = _minDeadline;
        gameAmount = _amount;
    }
    modifier ifAlive(){
                require(!killed,"Contract is dead");
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
    function setGameAmount(uint _amount) public onlyOwner{
        gameAmount = _amount;
        emit LogSetAmount(msg.sender,_amount);
    }
    function setGameMinDeadline(uint _minDeadline) public onlyOwner{
        minGameDeadline = _minDeadline;
        emit LogSetMinDeadline(msg.sender,_minDeadline);
    }
    //to play, player1 submits:
        //deadline in blocks, bytes32 hash as move
    function enrollPlayer1(uint _deadline,bytes32 _hashedMove,address _opponent)
    public payable whenNotPaused ifAlive {
        require(msg.value==gameAmount,"Deposit the right amount to play");
        require(_hashedMove != 0, "Submit a valid move");
        require(_opponent != address(0), "Submit a valid opponent address");
        require(_deadline >= minGameDeadline,"Deadline must be more than min deadline");
        require(games[_hashedMove].P1HashedMove == 0,"This hash has already been used");
        emit LogEnrollPlayer1(msg.sender,_opponent,_hashedMove,_deadline,msg.value);
        games[_hashedMove].player1 = msg.sender;
        games[_hashedMove].player2 = _opponent;
        games[_hashedMove].betAmount = msg.value;
        games[_hashedMove].P1HashedMove = _hashedMove;
        games[_hashedMove].GameDeadline = block.number.add(_deadline);
    }
    //to play, player2 submits:
        //the hashed move from p1 and thier own plain move and gameAmount
    function enrollPlayer2(bytes32 _hashedMove, uint _plainMove)
    public payable whenNotPaused ifAlive{
        require(msg.value==gameAmount,"Deposit the right amount to play");
        require(_plainMove>0 && _plainMove<4,"Submit a move between 1 and 3");
        address _player1 = games[_hashedMove].player1;
        require(_player1!=address(0),"You can not join a finished game");
        require(games[_hashedMove].player2==msg.sender,"You are not the opponent");
        emit LogEnrollPlayer2(msg.sender,_player1,_plainMove,_hashedMove,msg.value);
        games[_hashedMove].P2PlainMove = _plainMove;
        games[_hashedMove].GameDeadline = block.number.add(minGameDeadline);
    }
    //to determine winner
        //supply hash, p1 plain move and secret
    function revealPlayer1Move(bytes32 _p1Hash,uint _P1Plainmove,bytes32 _P1secret)
    public whenNotPaused ifAlive{
        require(_P1secret!=0,"provide a valid secret");
        require(_P1Plainmove>0 && _P1Plainmove<4,"Submit a move between 1 and 3");
        address _player1 = games[_p1Hash].player1;
        address _player2 = games[_p1Hash].player2;
        uint _p2PlainMove = games[_p1Hash].P2PlainMove;
        bytes32 _p1hashedMove = games[_p1Hash].P1HashedMove;
        uint betAmount = games[_p1Hash].betAmount;
        require(_player1==msg.sender,"You are not player 1");
        require(_p2PlainMove>0,"Player 2 has not played yet");
        require(_p1hashedMove == getHash(_P1secret,_P1Plainmove,msg.sender),"Wrong secret or move submitted");
        uint winner = whoWon(_P1Plainmove,_p2PlainMove);
        if(winner == 1){
            winnings[_player1] = winnings[_player1].add(betAmount.mul(2));
            emit LogWinner(_p1Hash,_player1,
            _player2,betAmount.mul(2));
        }else if(winner == 2){
            winnings[_player2] = winnings[_player2].add(betAmount.mul(2));
            emit LogWinner(_p1Hash,_player2,
            _player1,betAmount.mul(2));
        }else{
             winnings[_player1] = winnings[_player1].add(betAmount);
             winnings[_player2] = winnings[_player2].add(betAmount);
             emit LogDraw(_p1Hash,_player1,betAmount,
            _player2,betAmount);
        }
        games[_p1Hash].betAmount = 0;
        games[_p1Hash].player1 = address(0);
        games[_p1Hash].player2 = address(0);
        games[_p1Hash].P2PlainMove = 0;
        games[_p1Hash].GameDeadline = 0;
    }
    //in order to quit:
    /*
        player1 can cancel the game if:
        a. player2 didn't submit their plainMove2
        b. We passed the deadline
    */
    function quitPlayer1(bytes32 _p1Hash)
    public whenNotPaused ifAlive{
        address _player1 = games[_p1Hash].player1;
        address _player2 = games[_p1Hash].player2;
        uint _p2PlainMove = games[_p1Hash].P2PlainMove;
        uint betAmount = games[_p1Hash].betAmount;
        require(_player1==msg.sender,"You are not player 1");
        require(block.number>games[_p1Hash].GameDeadline,"This game has not yet expired");
        require(_p2PlainMove == 0,"Player 2 submited a move");
        winnings[_player1] = winnings[_player1].add(betAmount);
        emit LogQuit(_p1Hash,_player1,betAmount,_player2,_p2PlainMove);
        games[_p1Hash].betAmount = 0;
        games[_p1Hash].player1 = address(0);
        games[_p1Hash].player2 = address(0);
        games[_p1Hash].GameDeadline = 0;
    }
    /*
        player2 can cancel the game if:
        a. player2 submitted their plainMove2
        b. player1 didn't reveal their move
        c. We passed the deadline (please note that you need to reset the deadline of the game when player2 submit their plainMove2)
    */
    function quitPlayer2(bytes32 _p1Hash)
    public whenNotPaused ifAlive{
        address _player1 = games[_p1Hash].player1;
        address _player2 = games[_p1Hash].player2;
        uint _p2PlainMove = games[_p1Hash].P2PlainMove;
        uint betAmount = games[_p1Hash].betAmount;
        require(_player2==msg.sender,
        "You are not player 2");
        require(_p2PlainMove!=0,"Player 2 did not submit move");
        require(block.number>games[_p1Hash].GameDeadline,"The game has not expired");
        winnings[_player2] = winnings[_player2].add(betAmount.mul(2));
        emit LogQuit(_p1Hash,_player1,0,
            _player2,betAmount);
        games[_p1Hash].betAmount = 0;
        games[_p1Hash].player1 = address(0);
        games[_p1Hash].player2 = address(0);
        games[_p1Hash].GameDeadline = 0;
        games[_p1Hash].P2PlainMove = 0;
    }
    function withdraw()
    public whenNotPaused ifAlive{
        uint _amount = winnings[msg.sender];
        require(_amount>0,"You have no winnings");
        emit LogWithdrawal(msg.sender,_amount);
        winnings[msg.sender] = 0;
        msg.sender.transfer(_amount);
    }
}