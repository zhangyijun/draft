pragma solidity ^0.4.9;

contract SafeMath {
  function safeMul(uint a, uint b) internal returns (uint) {
    uint c = a * b;
    assert(a == 0 || c / a == b);
    return c;
  }

  function safeSub(uint a, uint b) internal returns (uint) {
    assert(b <= a);
    return a - b;
  }

  function safeAdd(uint a, uint b) internal returns (uint) {
    uint c = a + b;
    assert(c>=a && c>=b);
    return c;
  }

  function assert(bool assertion) internal {
    if (!assertion) throw;
  }
}

contract Token {
  /// @return total amount of tokens
  function totalSupply() constant returns (uint256 supply) {}

  /// @param _owner The address from which the balance will be retrieved
  /// @return The balance
  function balanceOf(address _owner) constant returns (uint256 balance) {}

  /// @notice send `_value` token to `_to` from `msg.sender`
  /// @param _to The address of the recipient
  /// @param _value The amount of token to be transferred
  /// @return Whether the transfer was successful or not
  function transfer(address _to, uint256 _value) returns (bool success) {}

  /// @notice send `_value` token to `_to` from `_from` on the condition it is approved by `_from`
  /// @param _from The address of the sender
  /// @param _to The address of the recipient
  /// @param _value The amount of token to be transferred
  /// @return Whether the transfer was successful or not
  function transferFrom(address _from, address _to, uint256 _value) returns (bool success) {}

  /// @notice `msg.sender` approves `_addr` to spend `_value` tokens
  /// @param _spender The address of the account able to transfer the tokens
  /// @param _value The amount of wei to be approved for transfer
  /// @return Whether the approval was successful or not
  function approve(address _spender, uint256 _value) returns (bool success) {}

  /// @param _owner The address of the account owning tokens
  /// @param _spender The address of the account able to transfer the tokens
  /// @return Amount of remaining tokens allowed to spent
  function allowance(address _owner, address _spender) constant returns (uint256 remaining) {}

  event Transfer(address indexed _from, address indexed _to, uint256 _value);
  event Approval(address indexed _owner, address indexed _spender, uint256 _value);

  uint public decimals;
  string public name;
}

contract TraderInterface {

  function deposit() payable {}

  function withdraw(uint amount) {}

  function depositToken(address token, uint amount) {}

  function withdrawToken(address token, uint amount) {}

  function order(address tokenGet, uint amountGet, address tokenGive, uint amountGive, uint expires, uint nonce) {}

  function trade(address tokenGet, uint amountGet, address tokenGive, uint amountGive, uint expires, uint nonce, address user, uint amount) {}

  function cancelOrder(address tokenGet, uint amountGet, address tokenGive, uint amountGive, uint expires, uint nonce){}
}

contract EtherTrader is SafeMath, TraderInterface {
  address public admin; //the admin address
  address public feeAccount; //the account that will receive fees
  uint public feeMake; //percentage times (1 ether)
  uint public feeTake; //percentage times (1 ether)
  uint public matchRate; //percentage times (1 ether)
  uint public matchGasRate; //percentage times (1 ether)
  mapping (address => mapping (address => uint)) public tokens; // (token => (user => balance)) (token=0 means Ether)
  //mapping (address => bytes32) public userOrders; // (user => order-hash)
  //mapping (bytes32 => mapping (token => uint)) public orderRemains; // (order-hash => [RemainAmountGet, RemainAmountGive])
  mapping (bytes32 =>  uint) public orderRemains; // (order-hash => RemainAmount (Give token amount))
  
  event Deposit(address token, address user, uint amount, uint balance);
  event Withdraw(address token, address user, uint amount, uint balance);
  event Order(address tokenGet, uint amountGet, address tokenGive, uint amountGive, uint expires, uint nonce, address user);
  event Trade(address tokenGet, uint amountGet, address tokenGive, uint amountGive, address get, address give);
  //event Cancel(address tokenGet, uint amountGet, address tokenGive, uint amountGive, uint expires, uint nonce, address user, uint8 v, bytes32 r, bytes32 s);
  //event Cancel(byte32 hash, uint amount, uint nonce, address user);
  event Cancel(address tokenGet, uint amountGet, address tokenGive, uint amountGive, uint expires, uint nonce, address user, uint remainAmount);
  
  function EtherTrader(address admin_, address feeAccount_, uint feeMake_, uint feeTake_, uint matchRate_, uint matchGasRate_) {
    admin = admin_;
    feeAccount = feeAccount_;
    feeMake = feeMake_;
    feeTake = feeTake_;
    matchRate = matchRate_;
    matchGasRate = matchGasRate_;
  }

  // support eth transfer directly
  function() payable {
    return deposit();
  }

  function changeAdmin(address admin_) {
    if (msg.sender != admin) throw;
    admin = admin_;
  }

  function changeFeeAccount(address feeAccount_) {
    if (msg.sender != admin) throw;
    feeAccount = feeAccount_;
  }

  function changeFeeMake(uint feeMake_) {
    if (msg.sender != admin) throw;
    if (feeMake_ > feeMake) throw;
    feeMake = feeMake_;
  }

  function changeFeeTake(uint feeTake_) {
    if (msg.sender != admin) throw;
    if (feeTake_ > feeTake ) throw;
    feeTake = feeTake_;
  }


  function deposit() payable {
    tokens[0][msg.sender] = safeAdd(tokens[0][msg.sender], msg.value);
    Deposit(0, msg.sender, msg.value, tokens[0][msg.sender]);
  }

  function withdraw(uint amount) {
    if (tokens[0][msg.sender] < amount) throw;
    tokens[0][msg.sender] = safeSub(tokens[0][msg.sender], amount);
    if (!msg.sender.call.value(amount)()) throw;
    Withdraw(0, msg.sender, amount, tokens[0][msg.sender]);
  }

  function depositToken(address token, uint amount) {
    //remember to call Token(address).approve(this, amount) or this contract will not be able to do the transfer on your behalf.
    if (token==0) throw;
    if (!Token(token).transferFrom(msg.sender, this, amount)) throw;
    tokens[token][msg.sender] = safeAdd(tokens[token][msg.sender], amount);
    Deposit(token, msg.sender, amount, tokens[token][msg.sender]);
  }

  function withdrawToken(address token, uint amount) {
    if (token==0) throw;
    if (tokens[token][msg.sender] < amount) throw;
    tokens[token][msg.sender] = safeSub(tokens[token][msg.sender], amount);
    if (!Token(token).transfer(msg.sender, amount)) throw;
    Withdraw(token, msg.sender, amount, tokens[token][msg.sender]);
  }

  function order(address tokenGet, uint amountGet, address tokenGive, uint amountGive, uint expires, uint nonce) {
    if (balanceOf(tokenGive, msg.sender) < amountGive) {
      throw;
    }
    bytes32 hash = sha256(this, tokenGet, amountGet, tokenGive, amountGive, expires, nonce, msg.sender);
    //orders[msg.sender][hash] = true;
    orderRemains[hash] = amountGive;
    Order(tokenGet, amountGet, tokenGive, amountGive, expires, nonce, msg.sender);
  }

  function trade(address tokenGet, uint amountGet, address tokenGive, uint amountGive, uint expires, uint nonce, address user, uint amount) {
    //amount is in amountGive terms
    address takeUser = msg.sender;
    bytes32 hash = sha256(this, tokenGet, amountGet, tokenGive, amountGive, expires, nonce, takeUser);
    if (amount <= 0 || 
      orderRemains[hash] < amount || 
      block.number > expires) {
      throw;
    }
    uint payAmount = safeMul(amountGet, amount) / amountGive;
    // TokenGive from order-user to take-user
    transfer(tokenGive, user, takeUser, amount);
    // TokenGet from take-user to order-user
    // calc payAmount first
    transfer(tokenGet, takeUser, user, payAmount);

    // calculate fee
    // takeUser pay take fee
    uint feeTakeXfer = safeMul(amount, feeTake) / (1 ether);
    transfer(tokenGive, takeUser, feeAccount, feeTakeXfer);
    // order-user pay make fee
    uint feeMakeXfer = safeMul(payAmount, feeMake) / (1 ether);
    transfer(tokenGet, user, feeAccount, feeMakeXfer);
    fillOrder(hash, amount);
    // Todo when ZERO remove from mapping?
    //Trade(tokenGet, amount, tokenGive, amountGive * amount / amountGet, user, msg.sender);
    Trade(tokenGet, amountGet * amount / amountGive, tokenGive, amount, user, msg.sender);
  }


  // only useb by trade
  function transfer(address token, address user1, address user2, uint amount) private {
    tokens[token][user1] = safeSub(tokens[token][user1], amount);
    tokens[token][user2] = safeAdd(tokens[token][user2], amount);
  }

  // Encourage make order policy: low make-fee, 
  // EveryOne can try 
  // and Maker will take some Fee and 
  // todo: add a batch API?
/*
  event Match (bytes32 hash1, bytes32 hash2, address maker, address token1, uint fee1, address token2, uint fee2);

  function matchTrade(address tokenGet1, uint amountGet1, address tokenGive1, uint amountGive1, uint expires1, uint nonce1, address user1,
    address tokenGet2, uint amountGet2, address tokenGive2, uint amountGive2, uint expires2, uint nonce2, address user2, uint amount) {
 // amount is give1 term, follow Trade
    // check pair first
    if (tokenGet1 != tokenGive2 || tokenGive1 != tokenGet2) {
      return;
    }
    // check hash and amount remain
    bytes32 hash1 = sha256(this, tokenGet1, amountGet1, tokenGive1, amountGive1, expires1, nonce1, user1);
    bytes32 hash2 = sha256(this, tokenGet2, amountGet2, tokenGive2, amountGive2, expires2, nonce2, user2);
    // order 2 giveAmount, calc by price2
    //uint give1 = amount
    uint get1 = safeMul(amountGet1, amount) / amountGive1;
    //uint get2  = amount;
    uint give2 = safeMul(amountGive2, amount) / amountGet2;    
    if (remaining(hash1) < amount || remaining(hash2) < give2) {
      return;
    }
    // check price: price1 should lower than price2
    if (get1 > give2) { // get2 == give1
      return;  // bad price
    }
    // Trade 1: by give amount
    // TokenGive from order-user to take-user
    transfer(tokenGive1, user1, user2, amount);
    fillOrder(hash1, amount);

    uint feeMake1 = safeMul(amount, feeMake) / (1 ether);
    transfer(tokenGive1, user2, feeAccount, feeMake1);
    // trade 2: by give2 amount
    transfer(tokenGive1, user2, user1, give2);
    fillOrder(hash2, give2);

    uint feeMake2 = safeMul(get1, feeMake) / (1 ether);
    transfer(tokenGive2, user1, feeAccount, feeMake2);
    // as fee and 
    uint matchGas = give2-get1; // 
    if (matchGas > 0) {
      transfer(tokenGive2, user1, feeAccount, matchGas);
    }

    // pay match-maker fee for current sender
    address matcher = msg.sender;
    uint matchFee1 = safeMul(feeMake1, matchRate)/(1 ether);
    uint matchFee2 = safeMul(feeMake2, matchRate)/(1 ether);
    if (matchGas > 0) {
      matchFee2 = safeAdd(matchFee2, safeMul(matchGas, matchGasRate)/(1 ether));
    }
    transfer(tokenGive1, feeAccount, matcher, matchFee1);
    transfer(tokenGive2, feeAccount, matcher, matchFee2);
    Trade(tokenGet1, get1, tokenGive1, amount, user1, user2);
    //Trade(tokenGet2, get2, tokenGive2, give2, user2, user1);
    Match(hash1, hash2, matcher, tokenGive1, matchFee1, tokenGive2, matchFee2);
    // success deal
    //return 0;   
  }
*/
  function cancelOrder(address tokenGet, uint amountGet, address tokenGive, uint amountGive, uint expires, uint nonce) {
    bytes32 hash = sha256(this, tokenGet, amountGet, tokenGive, amountGive, expires, nonce, msg.sender);
    if (orderRemains[hash] <= 0 || block.number > expires) {
      throw ;
    }
    uint remain = remaining(hash);
    fillOrder(hash, remain);
    Cancel(tokenGet, amountGet, tokenGive, amountGive, expires, nonce, msg.sender, remain);
  }

  function fillOrder(bytes32 hash, uint amount) private {
    orderRemains[hash] = safeSub(orderRemains[hash], amount);
  }

  function balanceOf(address token, address user) constant returns (uint) {
    return tokens[token][user];
  }

  function remaining(bytes32 hash) constant returns(uint) {
    return orderRemains[hash];
  }

/*
  function testTrade(address tokenGet, uint amountGet, address tokenGive, uint amountGive, uint expires, uint nonce, address user, uint8 v, bytes32 r, bytes32 s, uint amount, address sender) constant returns(bool) {
    if (!(
      tokens[tokenGet][sender] >= amount &&
      availableVolume(tokenGet, amountGet, tokenGive, amountGive, expires, nonce, user, v, r, s) >= amount
    )) return false;
    return true;
  }

  function availableVolume(address tokenGet, uint amountGet, address tokenGive, uint amountGive, uint expires, uint nonce, address user, uint8 v, bytes32 r, bytes32 s) constant returns(uint) {
    bytes32 hash = sha256(this, tokenGet, amountGet, tokenGive, amountGive, expires, nonce);
    if (amount <= 0 || 
      orderRemains[hash] < amount || 
      block.number > expires) {
      return 0;
    }
    uint available1 = orderRemains[hash];
    uint available2 = safeMul(tokens[tokenGive][user], amountGet) / amountGive;
    if (available1<available2) return available1;
    return available2;
  }

  function amountFilled(address tokenGet, uint amountGet, address tokenGive, uint amountGive, uint expires, uint nonce, address user, uint8 v, bytes32 r, bytes32 s) constant returns(uint) {
    bytes32 hash = sha256(this, tokenGet, amountGet, tokenGive, amountGive, expires, nonce);
    return orderFills[user][hash];
  }
*/
}
