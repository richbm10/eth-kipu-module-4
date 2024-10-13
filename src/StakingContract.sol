// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

contract StakingContract is
    Initializable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    IERC20 public stakingToken;
    uint256 public rewardRate; // Annual interest rate in basis points (1/100 of a percent)
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant SECONDS_IN_A_YEAR = 365 days;

    struct Stake {
        uint256 amount;
        uint256 lastUpdated;
        uint256 rewardDebt;
    }

    mapping(address => Stake) public stakes;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);

    function initialize(
        address _stakingToken,
        uint256 _rewardRate,
        address initialOwner
    ) external initializer {
        require(_stakingToken != address(0), "Invalid token address");

        stakingToken = IERC20(_stakingToken);
        rewardRate = _rewardRate;

        __Ownable_init(initialOwner);
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
    }

    function stake(uint256 _amount) external whenNotPaused nonReentrant {
        require(_amount > 0, "Amount must be greater than 0");
        updateReward(msg.sender);

        stakes[msg.sender].amount += _amount;
        stakes[msg.sender].lastUpdated = block.timestamp;

        stakingToken.transferFrom(msg.sender, address(this), _amount);
        emit Staked(msg.sender, _amount);
    }

    function withdraw(uint256 _amount) external nonReentrant {
        require(stakes[msg.sender].amount >= _amount, "Insufficient balance");
        updateReward(msg.sender);

        stakes[msg.sender].amount -= _amount;
        stakingToken.transfer(msg.sender, _amount);
        emit Withdrawn(msg.sender, _amount);
    }

    function claimReward() external nonReentrant {
        updateReward(msg.sender);

        uint256 reward = stakes[msg.sender].rewardDebt;
        require(reward > 0, "No reward available");
        require(
            stakingToken.balanceOf(address(this)) >= reward,
            "Insufficient treasury balance"
        );

        stakes[msg.sender].rewardDebt = 0;
        stakingToken.transfer(msg.sender, reward);
        emit RewardPaid(msg.sender, reward);
    }

    function updateReward(address _staker) internal {
        Stake storage userStake = stakes[_staker];
        if (userStake.lastUpdated > 0) {
            uint256 duration = block.timestamp - userStake.lastUpdated;
            uint256 reward = (((userStake.amount * rewardRate) / BASIS_POINTS) *
                duration) / SECONDS_IN_A_YEAR;
            userStake.rewardDebt += reward;
            userStake.lastUpdated = block.timestamp;
        }
    }

    function calculateReward(address _staker) public view returns (uint256) {
        Stake storage userStake = stakes[_staker];
        uint256 duration = block.timestamp - userStake.lastUpdated;
        uint256 reward = (((userStake.amount * rewardRate) / BASIS_POINTS) *
            duration) / SECONDS_IN_A_YEAR;
        return userStake.rewardDebt + reward;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
