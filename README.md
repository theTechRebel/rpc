# B9Lab Community Blockstars 2019 - Ethereum Developer Course
# Rock Paper Scissors Project

You will create a smart contract named RockPaperScissors whereby:
- Alice and Bob play the classic rock paper scissors game.
- to enrol, each player needs to deposit the right Ether amount, possibly zero.
- to play, each player submits their unique move.
- the contract decides and rewards the winner with all Ether wagered.

Of course there are many ways to implement it so we leave to yourselves to invent.

How can this be the 3rd project and not the 1st?? Try.

Stretch goals:
- make it a utility whereby any 2 people can decide to play against each other.
- reduce gas costs as much as you can.
- let players bet their previous winnings.
- how can you entice players to play, knowing that they may have their funding stuck in the contract if they faced an uncooperative player?

## Getting Started

Clone this repository locally:

```bash or cmd
git clone https://github.com/theTechRebel/rpc.git
```

Install dependencies with npm :

```bash or cmd
npm install
```

Build the App with webpack-cli:

(for windows)
```bash or cmd
.\node_modules\.bin\webpack-cli --mode development
```
(for unix):
```bash or cmd
./node_modules/.bin/webpack-cli --mode development
```
Start Ganache and launch a quickstart testnet

Deploy the smart contract onto your Ganache blockchain:

```bash or cmd
truffle migrate
```
Fire up an http server for development
```bash or cmd
npx http-server ./build/app/ -a 0.0.0.0 -p 8000 -c-1
```
Open the app in your browser with a Meta Mask plugin installed (preferably)

http://127.0.0.1:8000/index.html

