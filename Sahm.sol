pragma solidity ^0.6.3;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/math/SafeMath.sol";
import "https://github.com/BrightID/BrightID-SmartContract/blob/master/v4/IBrightID.sol";

contract Sahm is ERC20, Ownable {
    IBrightID public brightid;
    mapping(address => bool) public claimed;
    mapping (address => bool) public unlimited;
    uint256 public reward = 5 * 10 ** 17;
    uint256 public counter = 0;
    uint256 public stepSize = 1000000;
    uint256 public maxBalance = 20 * 10**18;

    event Unlimit(address addr, bool state);

    constructor() ERC20("Sahm", "Sahm") public {
    }

    function setBrightID(address addr) public onlyOwner {
        brightid = IBrightID(addr);
    }
    
    function unlimit(address addr, bool state) public onlyOwner {
        unlimited[addr] = state;
        emit Unlimit(addr, state);
    }

    function claim(
        address addr,
        address parent, 
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        bytes32 message = keccak256(abi.encodePacked(addr, parent));
        address signer = ecrecover(message, v, r, s);
        require(signer == addr, "not authorized");
        require (brightid.verifications(addr) > 0, "address is not verified");
        if (
            parent == address(0) ||
            brightid.verifications(parent) == 0 ||
            balanceOf(parent).add(reward) > maxBalance
        ) {
            parent = owner();
        }
        address tmp = addr;
        while (tmp != address(0)) {
            require (!claimed[tmp]);
            tmp = brightid.history(tmp);
        }
        claimed[addr] = true;
        counter = counter + 1;
        if (counter == stepSize) {
            counter = 0;
            reward = reward / 2;
            stepSize = stepSize * 2;
        }
        _mint(addr, reward);
        _mint(parent, reward);
        _mint(owner(), reward);
    }

    function reclaim(address addr) public {
        address tmp = brightid.history(addr);
        claimed[addr] = true;
        while (tmp != address(0) && tmp != owner() && !unlimited[tmp]) {
            uint amount = balanceOf(tmp);
            if (amount > 0) {
                _burn(tmp, amount);
                _mint(addr, amount);
            }
            tmp = brightid.history(tmp);
        }
    }

    function _beforeTokenTransfer(address f, address t, uint256 amount) internal virtual override {
        if (t != address(0) && t != owner() && !unlimited[t]) {
            require(balanceOf(t).add(amount) <= maxBalance, "Account balance exceeds 20");
            require(brightid.verifications(t) > 0, "to address is not verified");
            require(claimed[t], "Account did not claim or reclaim");
        }
        if (f != address(0) && f != owner() && !unlimited[f] && t != address(0)) {
            require(brightid.verifications(f) > 0 , "from address is not verified");
        }
    }
}
