# GameRPS

เริ่มต้นด้วยการสร้าง list address ที่เฉพาะสำหรับการเล่นเกม และจะมี constructor ที่จะทำการเพิ่มรายชื่อนั้นเข้าไป และจะให้ constructor นี้ทำหน้าที่ในการเชื่อมโยงกับ address ของ contract commitReveal ไปด้วยเลยครับ
    address[] List_Player; 
    constructor(address _commitRevealAddress) {
        List_Player.push(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4);
        List_Player.push(0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2);
        List_Player.push(0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db);
        List_Player.push(0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB);
        commitReveal = CommitReveal(_commitRevealAddress);
    }
จากนั้นจะเข้าสู่ฟังก์ชันการทำงานแรกคือการเพิ่มผู้เล่น โดยจะมีเงื่อนไขหลักๆอยู่ดังนี้
  1.ผู้เล่นต้องอยู่ในรายชื่อผู้เล่นที่ต้องการ
  2.จำเป็นต้องลงเงินเดิมพันเข้าสู่ contract
  3.จำนวนผู้เล่นต้องมีเพียงแค่สองคน
  4.ต้องการนับเวลาหลังจากที่ผู้เล่นคนแรกได้ทำการเพิ่มตัวเองเป็นผู้เล่นแล้ว (หากไม่มีคนเล่นด้วย เวลานี้จะเป็นตัวที่ทำให้ผู้เล่นนั้นสามารถถอนเงินออกได้หากครบระยะเวลาที่กำหนดไว้)
  โดยในฟังก์ชัน if(num_player > 0) ที่จะมีการเช็คว่าเป็นผู้เล่นคนแรกหรือไม่ (หากใช่ก็จะกด AddPlayerไม่ได้แล้ว)
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
เพื่อความเข้าใจง่ายจึงสร้างฟังก์ชันแยกสำหรับการจัดการกับ address ของผู้เล่นแยกออกมาครับ
    function setAccount(address payable _addressPlayer) private {
        num_player == 1 ? game.player1 = _addressPlayer : game.player2 = _addressPlayer; 
    }
ฟังก์ชันสำหรับเช็ค address ว่าอยู่ในรายชื่อเราหรือไม่
    function Player_listParty() internal view returns (bool check) {
        for(uint i = 0; i < List_Player.length; i++) {
            if(List_Player[i] == msg.sender) {
                return true;
            }
        }
        return false;
    }
ถัดมาจะเข้าสู่ฟังก์ชันของการ input หรือจะเรียกว่าการ commit ครับ โดยเงื่อนไขที่จำเป็นคือ
  1.ต้องเป็นผู้เล่นในเกมนี้ ซึ่งจะถูกกำหนดตั้งแต่ทำการ AddPlayer เข้ามาครับ
  2.ผู้เล่นต้องมากกว่า 0 คน (อย่างน้อย 1 คน) ไม่งั้นจะใส่ค่ามาไม่ได้ครับ
ซึ่งการทำงานของฟังก์ชันจะทำการเช็คว่าเป็นผู้เล่นคนไหนจากเงื่อนไข if และจะทำการเซ็ตคนตอบนั้นไว้พร้อมกับบล็อคครับ
(ในส่วนของ authorized_ending อันนี้เอาไว้สำหรับการ Force Endgame ครับ หากคนใดใส่คำตอบมาจะมีสิทธินี้ และสามารถกด Force Endgame ได้ หากครบระยะเวลาครับ)
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
        
        if(playing_count == 2) {
            timeUnit.resetStartTime();
        }
    }
ต่อมาจะเป็นฟังก์ชันรองรับการ refund ของผู้เล่น (ในกรณีที่กด AddPlayer เพียงอย่างเดียวครับ) เพราะหากไม่มีคนเข้ามาเล่นด้วย ก็จะสามารถ refund กลับไปได้ครับ และจะใช้ได้เพียงกรณีเดียวก็คือ มีผู้เล่นเข้ามาเล่นเพียง 1 คนครับ
    function refund() public payable {
        require(num_player == 1,"Can't refund");
        require(timeUnit.elapsedSeconds() > 360, "Waiting for 5 minute to refund!");
        game.player1.transfer(reward);
        resetGame();
    }
ต่อมาจะเป็นฟังก์ชันรองรับการจบเกมสำหรับคนที่การ input เข้ามา แต่อีกคนไม่ยอม input ด้วย ทำให้ไม่สามารถเล่นต่อได้ โดยจะมี authorized_ending ที่ทำการให้สิทธิตั้งแต่ทำการ input เข้ามาครับ โดยทั้งคู่ หากใครกด input เข้ามาจะมีสิทธิครับ และได้เงินคืนตามระยะเวลาครับ
    function ForcedEndGame() public {
        require(timeUnit.elapsedSeconds() > 360, "Waiting for 5 minute to Forced End");
        require(num_player == 1, "Can't do that");
        require(authorized_ending, "Can't do that");
        game.player1 == msg.sender ? game.player1.transfer(reward) : game.player2.transfer(reward);
        resetGame(); 
    }
ต่อมาจะเป็นฟังก์ชันการ reveal ตัวเลือกของผู้เล่นครับ โดยจะทำการเช็คว่าเป็นผู้เล่นคนใดที่ทำการ Reveal เข้ามาผ่านเงื่อนไข if ครับ
: ซึ่งโดยเงื่อนไขทั้งสองนั้นจะมีเงื่อนไขหลักๆอยู่ดังนี้ครับ
  1.ต้องทำการ commit มาก่อนเท่านั้น
  2.ต้องไม่ใช่การ reveal ซ้ำสองรอบครับ (อันนี้ไม่ค่อยเข้าใจ แต่เพราะเห็นของอาจารย์มีเลยใส่มาครับ) ปล.เพราะถึง reveal ซ้ำก็คิดว่าไม่ได้มีผลอะไร ตามความเข้าใจน่าจะแค่บอกเฉยๆว่ามันถูก reveal แล้วละมั้งครับ
  3.ต้องไม่ใช่การ reveal ในบล็อกเดียวกันครับ
  4.ต้อง reveal ภายในระยะเวลา (block) ที่กำหนดครับ
  5.reveal ที่ใส่มา ต้องมีค่าเท่ากับ commit หลังจากที่นำ reveal ไป hash แล้วครับ (ค่า Hash Reveal = commmit)

หลังจากครบเงื่อนไขทั้งหมด ก้จะทำการบันทึก choice ของผู้เล่นคนนั้น โดยดึงบิตท้าย 2 ตัวแล้วแปลงเลขกลับครับ

และในช่วงสุดท้ายของฟังก์ชัน ก็จะทำการนับว่ามีการ reveal ครบทั้งคู่ จากนั้นจึงตัดสินครับ
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
ฟังก์ชัน reset เกมครับ ให้อีกครั้งได้
    function resetGame() internal {
        delete game;
        count_reveal = 0;
        playing_count = 0;
        player_inGame[game.player1] = false;
        player_inGame[game.player2] = false;
        authorized_ending = false;
    }
ต่อมาจะเป็นฟังก์ชันการตัดสินครับ ซึ่งก็จะนำค่าตัวเลือกของผู้เล่นที่บันทึกไว้มาใช้เลยครับ ซึ่งก็จะใช้หลักของ Modular Math มาใช้ครับ เพียงแค่เช็คให้ได้ว่าค่าอีกค่าน้อยกว่าค่าอีกค่านึง (โดยอาจมีลำดับการตายตัวของความห่างระหว่างค่านั้นไม่เท่ากันหากมีเงื่อนไขเพิ่ม เช่น Spock กับ lizard แล้วมี dragon เพิ่มเข้าไป แต่ทั้งที่ทั้งนั้นจะนัยของระยะห่างตายตัวครับ แค่เพิ่ม pigeon มา แต่สุดท้าย hole เท่าเดิมครับ แค่ต้องจับหลักให้ได้ ในที่นี้จึงแค่เพิ่มเงื่อนไขการเช็คมานิดหน่อย เช่น (game.player1_choice+1) % 5 == game.player2_choice || (game.player1_choice+1) % 5 == game.player2_choice-1 ) ครับ)
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

อธิบายโค้ดที่ป้องกันการ lock เงินไว้ใน contract
Ans. 
  การป้องกันการ lock เงิน ในกรณีไม่มีคนเล่นด้วย ก็จะทำการเช็คตัวแปรของผู้เล่นครับ ว่าต้องมีเพียง 1 คน และตามระยะเวลาที่กำหนดครับ หากมีคนเข้ามาเล่นด้วยแล้ว ก็จะกดไม่ได้ครับ
  function refund() public payable {
        require(num_player == 1,"Can't refund");
        require(timeUnit.elapsedSeconds() > 360, "Waiting for 5 minute to refund!");
        game.player1.transfer(reward);
        resetGame();
    }
  การป้องกันการ lock เงิน ในกรณีที่มีคน input แค่คนเดียว จะแก้ปัญหาโดยการให้สิทธิตอนผู้เล่นทำการ input มาครับ โดยหากมีสิทธิ และมี count_input เพียง 1 ก็จะ force end ได้ครับ (หากอีกคนไม่กด input ก็จะไม่มีสิทธินี้ครับ)
  function ForcedEndGame() public {
        require(timeUnit.elapsedSeconds() > 360, "Waiting for 5 minute to Forced End");
        require(count_input == 1, "Can't do that");
        require(authorized_ending, "Can't do that");
        game.player1 == msg.sender ? game.player1.transfer(reward) : game.player2.transfer(reward);
        resetGame(); 
    }

อธิบายโค้ดส่วนที่ทำการซ่อน choice และ commit

อธิบายโค้ดส่วนที่จัดการกับความล่าช้าที่ผู้เล่นไม่ครบทั้งสองคนเสียที

อธิบายโค้ดส่วนทำการ reveal และนำ choice มาตัดสินผู้ชนะ
