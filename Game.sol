// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

import "./timeUnit.sol";
import "./commitReveal.sol";

contract Game {
    CommitReveal public commitReveal;

    TimeUnit public timeUnit = new TimeUnit();
    
    struct GameData {
        address payable player1;
        address payable player2;
        bytes32 player1_committed;
        bytes32 player2_committed;
        bool player1_revealed;
        bool player2_revealed;
        uint64 player1_block;
        uint64 player2_block;
        uint player1_choice;
        uint player2_choice;
    }

    GameData public game;
    uint public count_reveal;
    uint public reward;
    uint public num_player;
    mapping(address => bool) public player_inGame;
    uint public playing_count;
    bool authorized_ending;
    count_input;

    address[] List_Player; 
    
    
    constructor(address _commitRevealAddress) {
        List_Player.push(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4);
        List_Player.push(0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2);
        List_Player.push(0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db);
        List_Player.push(0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB);
        commitReveal = CommitReveal(_commitRevealAddress);
    }

    function AddPlayer() public payable {
        require(Player_listParty(), "You not in list-party");
        require(msg.value == 5 ether, "Need 5 Eth to bet in this round!");
        require(num_player < 2, "Already Full!");
        if(num_player > 0) {
            require(msg.sender != game.player1, "You've been bet");
        }
        if(num_player == 0){
            timeUnit.setStartTime();
        }
        player_inGame[msg.sender] = true;
        reward += msg.value; 
        num_player++;
        setAccount(payable(msg.sender));
    }

    function setAccount(address payable _addressPlayer) private {
        num_player == 1 ? game.player1 = _addressPlayer : game.player2 = _addressPlayer; 
    }

    function Player_listParty() internal view returns (bool check) {
        for(uint i = 0; i < List_Player.length; i++) {
            if(List_Player[i] == msg.sender) {
                return true;
            }
        }
        return false;
    }
    
    function inputPlayer(bytes32 _input) public {
        require(player_inGame[msg.sender], "You are not in this round!");
        require(game.player1 != address(0) && game.player2 != address(0), "Not enough players!");
        
        player_inGame[msg.sender] = false;

        if (game.player1 == msg.sender) {
            game.player1_committed = _input;
            game.player1_block = uint64(block.number);
            authorized_ending = true;
        }else {
            game.player2_committed = _input;
            game.player2_block = uint64(block.number);
            authorized_ending = true;
        }

        playing_count++;
        count_input++;

        if(playing_count == 2) {
            timeUnit.resetStartTime();
        }
    }

    function refund() public payable {
        require(num_player == 1,"Can't refund");
        require(timeUnit.elapsedSeconds() > 360, "Waiting for 5 minute to refund!");
        game.player1.transfer(reward);
        resetGame();
    }

    function ForcedEndGame() public {
        require(timeUnit.elapsedSeconds() > 360, "Waiting for 5 minute to Forced End");
        require(count_input == 1, "Can't do that");
        require(authorized_ending, "Can't do that");
        game.player1 == msg.sender ? game.player1.transfer(reward) : game.player2.transfer(reward);
        resetGame(); 
    }

    function reveal_choice(bytes32 _reveal) public {
        
        if (game.player1 == msg.sender) { 
            require(game.player1_committed != 0, "You didn't commit");
            require(game.player1_revealed ==false, "CommitReveal::reveal: Already revealed");
            require(uint64(block.number)>game.player1_block,"CommitReveal::reveal: Reveal and commit happened on the same block");
            require(uint64(block.number)<game.player1_block+250,"CommitReveal::reveal: Revealed too late");
            require(commitReveal.getHash(_reveal) == game.player1_committed, "Your commit doesn't match reveal");
            
            game.player1_choice = uint8(uint256(_reveal) & 0x003);
        }
        if (game.player2 == msg.sender) {
            require(game.player2_committed != 0, "You didn't commit");
            require(game.player2_revealed ==false, "CommitReveal::reveal: Already revealed");
            require(uint64(block.number)>game.player2_block,"CommitReveal::reveal: Reveal and commit happened on the same block");
            require(uint64(block.number)<game.player2_block+250,"CommitReveal::reveal: Revealed too late");
            require(commitReveal.getHash(_reveal) == game.player2_committed, "Your commit doesn't match reveal");
            
            game.player2_choice = uint8(uint256(_reveal) & 0x003);
        }  
        
        count_reveal++;
        if (count_reveal == 2) {

            determineOutcomeSL();
            
        }
    }
    
    function resetGame() internal {
        delete game;
        count_reveal = 0;
        playing_count = 0;
        player_inGame[game.player1] = false;
        player_inGame[game.player2] = false;
        authorized_ending = false;
    }
    
    function determineOutcomeSL() internal {
        if(game.player1_choice == game.player2_choice){
            game.player1.transfer(reward/2);
            game.player2.transfer(reward/2);
        }
        else if((game.player1_choice+1) % 5 == game.player2_choice || (game.player1_choice+1) % 5 == game.player2_choice-1 ) {
            game.player2.transfer(reward);
        }
        else{
            game.player1.transfer(reward);
        }
        resetGame();
    }
}
