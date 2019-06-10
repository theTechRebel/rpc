const RPC = artifacts.require("RPC");

contract('RPC',accounts=>{
    const[player1,player2,owner] = accounts;
    let instance;

    const getEventResult = (txObj, eventName) => {
        const event = txObj.logs.find(log => log.event === eventName);
        if (event) {
          return event.args;
        } else {
          return undefined;
        }
      };

    const mineBlock = function () {
    return new Promise((resolve, reject) => {
        web3.currentProvider.send({
        jsonrpc: "2.0",
        method: "evm_mine"
        }, (err, result) => {
        if(err){ return reject(err) }
        return resolve(result)
        });
    })
    };

    beforeEach(async() =>{
		instance = await RPC.new(500,10, { from: owner });
    });

    it("should fail to generate hash with invalid move", async()=>{
        const secret = "game";
        var converted = await web3.utils.fromAscii(secret);
        try{
        var hash = await instance.getHash(converted,0,player1);
        }catch(ex){
            console.log(ex);
            try{
                var hash = await instance.getHash(converted,4,player1);
                }catch(ex){
                    console.log(ex);
                    return true;
                }
        }
        throw new Error("generating hash should have failed")
    });

    it("should fail to enroll given shorter deadline", async()=>{
        const secret = "game";
        const ether = 500;
        var converted = await web3.utils.fromAscii(secret);
        var hash = await instance.getHash(converted,1,player1);
        try{
        const tx = await instance.enrollPlayer1(7,hash,player2,{value:ether,from:player1});
        }catch(ex){
            console.log(ex);
            return true;
        }
        throw new Error("Enrollment should have failed.");
    });

    it("should enroll player 1 successfully", async()=>{
        const secret = "game";
        const ether = 500;
        var converted = await web3.utils.fromAscii(secret);
        var hash = await instance.getHash(converted,1,player1);
        const tx = await instance.enrollPlayer1(17,hash,player2,{value:ether,from:player1});
        assert.isTrue(tx.receipt.status,"transaction must be succesful");
    });

    it("should fail to enroll player 2 given non-existing hash", async()=>{
        const secret = "hash";
        const ether = 500;
        var converted = await web3.utils.fromAscii(secret);
        var hash = await instance.getHash(converted,1,player1);
        try{
        const tx = await instance.enrollPlayer2(hash,1,{value:ether,from:player2});
        }catch(ex){
            console.log(ex);
            return true;
        }
        throw new Error("Should have failed because hash is not in game");
    });

    it("should fail to enroll player 2 given invalid move", async()=>{
        const secret = "game";
        const ether = 500;
        var converted = await web3.utils.fromAscii(secret);
        var hash = await instance.getHash(converted,1,player1);
        const tx = await instance.enrollPlayer1(17,hash,player2,{value:ether,from:player1});
        assert.isTrue(tx.receipt.status,"transaction must be succesful");
        try{
        const tx = await instance.enrollPlayer2(hash,0,{value:ether,from:player2});
        }catch(ex){
            console.log(ex);
            try{
                const tx = await instance.enrollPlayer2(hash,4,{value:ether,from:player2});
                }catch(ex){
                    console.log(ex);
                    return true;
                }
        }
        throw new Error("Should have failed because moves 0 and 4 are invalid");
    });

    it("should enroll player 2 succesfully", async()=>{
        const secret = "game";
        const ether = 500;
        var converted = await web3.utils.fromAscii(secret);
        var hash = await instance.getHash(converted,1,player1);
        var tx = await instance.enrollPlayer1(17,hash,player2,{value:ether,from:player1});
        assert.isTrue(tx.receipt.status,"transaction must be succesful");
        tx = await instance.enrollPlayer2(hash,1,{value:ether,from:player2});
        assert.isTrue(tx.receipt.status,"transaction must be succesful");
    });

    it("should fail to reveal player 1 move before player 2 has played", async()=>{
        const secret = "game";
        const ether = 500;
        var converted = await web3.utils.fromAscii(secret);
        var hash = await instance.getHash(converted,1,player1);
        var tx = await instance.enrollPlayer1(17,hash,player2,{value:ether,from:player1});
        assert.isTrue(tx.receipt.status,"transaction must be succesful");
          try{
            tx = await instance.revealPlayer1Move(hash,1,converted,{from:player1});
          }catch(ex){
            console.log(ex);
              return true;
          }
        throw new Error("Should have failed because deadline has not been met");
    });

    it("should fail to quit game by player 1 before deadline", async()=>{
        const secret = "game";
        const ether = 500;
        var converted = await web3.utils.fromAscii(secret);
        var hash = await instance.getHash(converted,1,player1);
        var tx = await instance.enrollPlayer1(17,hash,player2,{value:ether,from:player1});
        assert.isTrue(tx.receipt.status,"transaction must be succesful");
        for(i=0;i<15;i++){
            await mineBlock();
          }
          try{
            tx = await instance.quitPlayer1(hash,{from:player1});
          }catch(ex){
            console.log(ex);
              return true;
          }
        throw new Error("Should have failed because deadline has not been met");
    });

    it("should fail to enroll different opponent as player2 besides given address", async()=>{
        const secret = "game";
        const ether = 500;
        var converted = await web3.utils.fromAscii(secret);
        var hash = await instance.getHash(converted,1,player1);
        var tx = await instance.enrollPlayer1(17,hash,player2,{value:ether,from:player1});
        assert.isTrue(tx.receipt.status,"transaction must be succesful");
          try{
            tx = await instance.enrollPlayer2(hash,2,{value:ether,from:owner});
          }catch(ex){
            console.log(ex);
              return true;
          }
        throw new Error("Should have failed because owner is not player2");
    });

    it("should quit game by player 1 after deadline", async()=>{
        const secret = "game";
        const ether = 500;
        var converted = await web3.utils.fromAscii(secret);
        var hash = await instance.getHash(converted,1,player1);
        var tx = await instance.enrollPlayer1(17,hash,player2,{value:ether,from:player1});
        assert.isTrue(tx.receipt.status,"transaction must be succesful");
        for(i=0;i<18;i++){
            await mineBlock();
          }
        tx = await instance.quitPlayer1(hash,{from:player1});
        assert.isTrue(tx.receipt.status,"transaction must be succesful");
    });

    it("should fail to quit game by player 2 after player 1 reveals move", async()=>{
        const secret = "game";
        const ether = 500;
        var converted = await web3.utils.fromAscii(secret);
        var hash = await instance.getHash(converted,1,player1);
        var tx = await instance.enrollPlayer1(17,hash,player2,{value:ether,from:player1});
        assert.isTrue(tx.receipt.status,"transaction must be succesful");
        tx = await instance.enrollPlayer2(hash,2,{value:ether,from:player2});
        assert.isTrue(tx.receipt.status,"transaction must be succesful");
        tx = await instance.revealPlayer1Move(hash,1,converted,{from:player1});
        assert.isTrue(tx.receipt.status,"transaction must be succesful");
          try{
            tx = await instance.quitPlayer2(hash,{from:player2});
          }catch(ex){
              console.log(ex);
              return true;
          }
        throw new Error("Should have failed because player 1 revealed move");
    });

    it("should fail to quit game by player 2 before deadline", async()=>{
        const secret = "game";
        const ether = 500;
        var converted = await web3.utils.fromAscii(secret);
        var hash = await instance.getHash(converted,1,player1);
        var tx = await instance.enrollPlayer1(17,hash,player2,{value:ether,from:player1});
        assert.isTrue(tx.receipt.status,"transaction must be succesful");
        tx = await instance.enrollPlayer2(hash,2,{value:ether,from:player2});
        assert.isTrue(tx.receipt.status,"transaction must be succesful");
        for(i=0;i<8;i++){
            await mineBlock();
          }
          try{
        tx = await instance.quitPlayer2(hash,{from:player2});
        }catch(ex){
            console.log(ex);
            return true;
        }
        throw new Error("should fail because minimum time has not been met");
    });

    it("should quit game by player 2 before player 1 reveals move after deadline", async()=>{
        const secret = "game";
        const ether = 500;
        var converted = await web3.utils.fromAscii(secret);
        var hash = await instance.getHash(converted,1,player1);
        var tx = await instance.enrollPlayer1(17,hash,player2,{value:ether,from:player1});
        assert.isTrue(tx.receipt.status,"transaction must be succesful");
        tx = await instance.enrollPlayer2(hash,2,{value:ether,from:player2});
        assert.isTrue(tx.receipt.status,"transaction must be succesful");
        for(i=0;i<15;i++){
            await mineBlock();
          }
        tx = await instance.quitPlayer2(hash,{from:player2});
        assert.isTrue(tx.receipt.status,"transaction must be succesful");
    });

    it("should take player 1 and player 2 moves and determine winnings amount given gas costs", async()=>{
        const secret = "game";
        const ether = 500;

        const p1BalBefore = web3.utils.toBN(await web3.eth.getBalance(player1));

        var converted = await web3.utils.fromAscii(secret);
        var hash = await instance.getHash(converted,1,player1);
        const tx1 = await instance.enrollPlayer1(17,hash,player2,{value:ether,from:player1});
        assert.isTrue(tx1.receipt.status,"transaction must be succesful");
        tx = await instance.enrollPlayer2(hash,3,{value:ether,from:player2});
        assert.isTrue(tx.receipt.status,"transaction must be succesful");
        const tx2 = await instance.revealPlayer1Move(hash,1,converted,{from:player1});
        assert.isTrue(tx2.receipt.status,"transaction must be succesful");
        const tx3 = await instance.withdraw({from:player1});
        assert.isTrue(tx3.receipt.status,"transaction must be succesful");
        try{
        await instance.withdraw({from:player2});
        }catch(ex){
            console.log(ex);
            //calculate transaction cost
            const transaction1 =  await web3.eth.getTransaction(tx1.tx);
            const transaction2 =  await web3.eth.getTransaction(tx2.tx);
            const transaction3 =  await web3.eth.getTransaction(tx3.tx);
            // transaction cost = gasUsed x gasPrice
            const txCost1 = web3.utils.toBN(tx1.receipt.gasUsed).mul(web3.utils.toBN(transaction1.gasPrice));
            const txCost2 = web3.utils.toBN(tx2.receipt.gasUsed).mul(web3.utils.toBN(transaction2.gasPrice));
            const txCost3 = web3.utils.toBN(tx3.receipt.gasUsed).mul(web3.utils.toBN(transaction3.gasPrice));
            
            //3. compare
            const p1BalAfter = web3.utils.toBN(await web3.eth.getBalance(player1));
            const withdrawn = p1BalAfter.sub((p1BalBefore.sub((txCost1.add(txCost2).add(txCost3)))));
            assert.equal(withdrawn.toString(),ether.toString(),"Withdrawn amount should equal all bets");
            return true;
        }
        throw new Error("there should be no ether for player 2 to withdraw");
    });

    it("should take player 1 and player 2 moves in a draw and determine withdrawn amount given gas costs", async()=>{
        const secret = "game";
        const ether = 500;

        const p1BalBefore = web3.utils.toBN(await web3.eth.getBalance(player1));

        var converted = await web3.utils.fromAscii(secret);
        var hash = await instance.getHash(converted,1,player1);
        const tx1 = await instance.enrollPlayer1(17,hash,player2,{value:ether,from:player1});
        assert.isTrue(tx1.receipt.status,"transaction must be succesful");
        tx = await instance.enrollPlayer2(hash,1,{value:ether,from:player2});
        assert.isTrue(tx.receipt.status,"transaction must be succesful");
        const tx2 = await instance.revealPlayer1Move(hash,1,converted,{from:player1});
        assert.isTrue(tx2.receipt.status,"transaction must be succesful");
        const tx3 = await instance.withdraw({from:player1});
        assert.isTrue(tx3.receipt.status,"transaction must be succesful");
        
        //calculate transaction cost
        const transaction1 =  await web3.eth.getTransaction(tx1.tx);
        const transaction2 =  await web3.eth.getTransaction(tx2.tx);
        const transaction3 =  await web3.eth.getTransaction(tx3.tx);
        // transaction cost = gasUsed x gasPrice
        const txCost1 = web3.utils.toBN(tx1.receipt.gasUsed).mul(web3.utils.toBN(transaction1.gasPrice));
        const txCost2 = web3.utils.toBN(tx2.receipt.gasUsed).mul(web3.utils.toBN(transaction2.gasPrice));
        const txCost3 = web3.utils.toBN(tx3.receipt.gasUsed).mul(web3.utils.toBN(transaction3.gasPrice));
        
        //3. compare
        const p1BalAfter = web3.utils.toBN(await web3.eth.getBalance(player1));
        const withdrawn = p1BalAfter.sub((p1BalBefore.sub((txCost1.add(txCost2).add(txCost3)))));
        assert.equal(withdrawn.toString(),"0","Withdrawn amount should equal 0");
    });

})