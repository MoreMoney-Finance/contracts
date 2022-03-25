// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./VeERC20Upgradeable.sol";
import "./Whitelist.sol";
import "../../interfaces/IMasterPlatypus.sol";
import "./Math.sol";
import "../../interfaces/IVePtp.sol";
import "../../interfaces/IPlatypusNFT.sol";

/// @title VePtp
/// @notice Platypus Venom: the staking contract for PTP, as well as the token used for governance.
/// Note Venom does not seem to hurt the Platypus, it only makes it stronger.
/// Allows depositing/withdraw of ptp and staking/unstaking ERC721.
/// Here are the rules of the game:
/// If you stake ptp, you generate vePtp at the current `generationRate` until you reach `maxCap`
/// If you unstake any amount of ptp, you loose all of your vePtp.
/// ERC721 staking does not affect generation nor cap for the moment, but it will in a future upgrade.
/// Note that it's ownable and the owner wields tremendous power. The ownership
/// will be transferred to a governance smart contract once Platypus is sufficiently
/// distributed and the community can show to govern itself.
contract VePtp is
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    VeERC20Upgradeable,
    IVePtp
{
    using SafeERC20 for IERC20;

    struct UserInfo {
        uint256 amount; // ptp staked by user
        uint256 lastRelease; // time of last vePtp claim or first deposit if user has not claimed yet
        // the id of the currently staked nft
        // important: the id is offset by +1 to handle tokenID = 0
        uint256 stakedNftId;
    }

    /// @notice the ptp token
    IERC20 public ptp;

    /// @notice the masterPlatypus contract
    IMasterPlatypus public masterPlatypus;

    /// @notice the NFT contract
    IPlatypusNFT public nft;

    /// @dev Magic value for onERC721Received
    /// Equals to bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))
    bytes4 private constant ERC721_RECEIVED = 0x150b7a02;

    /// @notice max vePtp to staked ptp ratio
    /// Note if user has 10 ptp staked, they can only have a max of 10 * maxCap vePtp in balance
    uint256 public maxCap;

    /// @notice the rate of vePtp generated per second, per ptp staked
    uint256 public generationRate;

    /// @notice invVvoteThreshold threshold.
    /// @notice voteThreshold is the tercentage of cap from which votes starts to count for governance proposals.
    /// @dev inverse of the threshold to apply.
    /// Example: th = 5% => (1/5) * 100 => invVoteThreshold = 20
    /// Example 2: th = 3.03% => (1/3.03) * 100 => invVoteThreshold = 33
    /// Formula is invVoteThreshold = (1 / th) * 100
    uint256 public invVoteThreshold;

    /// @notice whitelist wallet checker
    /// @dev contract addresses are by default unable to stake ptp, they must be previously whitelisted to stake ptp
    Whitelist public whitelist;

    /// @notice user info mapping
    mapping(address => UserInfo) public users;

    /// @notice events describing staking, unstaking and claiming
    event Staked(address indexed user, uint256 indexed amount);
    event Unstaked(address indexed user, uint256 indexed amount);
    event Claimed(address indexed user, uint256 indexed amount);

    /// @notice events describing NFT staking and unstaking
    event StakedNft(address indexed user, uint256 indexed nftId);
    event UnstakedNft(address indexed user, uint256 indexed nftId);

    function initialize(
        IERC20 _ptp,
        IMasterPlatypus _masterPlatypus,
        IPlatypusNFT _nft
    ) public initializer {
        require(address(_masterPlatypus) != address(0), "zero address");
        require(address(_ptp) != address(0), "zero address");

        // Initialize vePTP
        __ERC20_init("Platypus Venom", "vePTP");
        __Ownable_init();
        __ReentrancyGuard_init_unchained();
        __Pausable_init_unchained();

        // set generationRate (vePtp per sec per ptp staked)
        generationRate = 3888888888888;

        // set maxCap
        maxCap = 100;

        // set inv vote threshold
        // invVoteThreshold = 20 => th = 5
        invVoteThreshold = 20;

        // set master platypus
        masterPlatypus = _masterPlatypus;

        // set ptp
        ptp = _ptp;

        // set nft, can be zero address at first
        nft = _nft;
    }

    /**
     * @dev pause pool, restricting certain operations
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev unpause pool, enabling certain operations
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice sets masterPlatpus address
    /// @param _masterPlatypus the new masterPlatypus address
    function setMasterPlatypus(IMasterPlatypus _masterPlatypus)
        external
        onlyOwner
    {
        require(address(_masterPlatypus) != address(0), "zero address");
        masterPlatypus = _masterPlatypus;
    }

    /// @notice sets NFT contract address
    /// @param _nft the new NFT contract address
    function setNftAddress(IPlatypusNFT _nft) external onlyOwner {
        require(address(_nft) != address(0), "zero address");
        nft = _nft;
    }

    /// @notice sets whitelist address
    /// @param _whitelist the new whitelist address
    function setWhitelist(Whitelist _whitelist) external onlyOwner {
        require(address(_whitelist) != address(0), "zero address");
        whitelist = _whitelist;
    }

    /// @notice sets maxCap
    /// @param _maxCap the new max ratio
    function setMaxCap(uint256 _maxCap) external onlyOwner {
        require(_maxCap != 0, "max cap cannot be zero");
        maxCap = _maxCap;
    }

    /// @notice sets generation rate
    /// @param _generationRate the new max ratio
    function setGenerationRate(uint256 _generationRate) external onlyOwner {
        require(_generationRate != 0, "generation rate cannot be zero");
        generationRate = _generationRate;
    }

    /// @notice sets invVoteThreshold
    /// @param _invVoteThreshold the new var
    /// Formula is invVoteThreshold = (1 / th) * 100
    function setInvVoteThreshold(uint256 _invVoteThreshold) external onlyOwner {
        // onwner should set a high value if we do not want to implement an important threshold
        require(_invVoteThreshold != 0, "invVoteThreshold cannot be zero");
        invVoteThreshold = _invVoteThreshold;
    }

    /// @notice checks wether user _addr has ptp staked
    /// @param _addr the user address to check
    /// @return true if the user has ptp in stake, false otherwise
    function isUser(address _addr) public view override returns (bool) {
        return users[_addr].amount > 0;
    }

    /// @notice returns staked amount of ptp for user
    /// @param _addr the user address to check
    /// @return staked amount of ptp
    function getStakedPtp(address _addr)
        external
        view
        override
        returns (uint256)
    {
        return users[_addr].amount;
    }

    /// @dev explicity override multiple inheritance
    function totalSupply()
        public
        view
        override(VeERC20Upgradeable, IVeERC20)
        returns (uint256)
    {
        return super.totalSupply();
    }

    /// @dev explicity override multiple inheritance
    function balanceOf(address account)
        public
        view
        override(VeERC20Upgradeable, IVeERC20)
        returns (uint256)
    {
        return super.balanceOf(account);
    }

    /// @notice deposits PTP into contract
    /// @param _amount the amount of ptp to deposit
    function deposit(uint256 _amount)
        external
        override
        nonReentrant
        whenNotPaused
    {
        require(_amount > 0, "amount to deposit cannot be zero");

        // assert call is not coming from a smart contract
        // unless it is whitelisted
        _assertNotContract(msg.sender);

        if (isUser(msg.sender)) {
            // if user exists, first, claim his vePTP
            _claim(msg.sender);
            // then, increment his holdings
            users[msg.sender].amount += _amount;
        } else {
            // add new user to mapping
            users[msg.sender].lastRelease = block.timestamp;
            users[msg.sender].amount = _amount;
        }

        // Request Ptp from user
        ptp.safeTransferFrom(msg.sender, address(this), _amount);
    }

    /// @notice asserts addres in param is not a smart contract.
    /// @notice if it is a smart contract, check that it is whitelisted
    /// @param _addr the address to check
    function _assertNotContract(address _addr) private view {
        if (_addr != tx.origin) {
            require(
                address(whitelist) != address(0) && whitelist.check(_addr),
                "Smart contract depositors not allowed"
            );
        }
    }

    /// @notice claims accumulated vePTP
    function claim() external override nonReentrant whenNotPaused {
        require(isUser(msg.sender), "user has no stake");
        _claim(msg.sender);
    }

    /// @dev private claim function
    /// @param _addr the address of the user to claim from
    function _claim(address _addr) private {
        uint256 amount = _claimable(_addr);

        // update last release time
        users[_addr].lastRelease = block.timestamp;

        if (amount > 0) {
            emit Claimed(_addr, amount);
            _mint(_addr, amount);
        }
    }

    /// @notice Calculate the amount of vePTP that can be claimed by user
    /// @param _addr the address to check
    /// @return amount of vePTP that can be claimed by user
    function claimable(address _addr) external view returns (uint256) {
        require(_addr != address(0), "zero address");
        return _claimable(_addr);
    }

    /// @dev private claim function
    /// @param _addr the address of the user to claim from
    function _claimable(address _addr) private view returns (uint256) {
        UserInfo storage user = users[_addr];

        // get seconds elapsed since last claim
        uint256 secondsElapsed = block.timestamp - user.lastRelease;

        // calculate pending amount
        // Math.mwmul used to multiply wad numbers
        uint256 pending = Math.wmul(
            user.amount,
            secondsElapsed * generationRate
        );

        // get user's vePTP balance
        uint256 userVePtpBalance = balanceOf(_addr);

        // user vePTP balance cannot go above user.amount * maxCap
        uint256 maxVePtpCap = user.amount * maxCap;

        // first, check that user hasn't reached the max limit yet
        if (userVePtpBalance < maxVePtpCap) {
            // then, check if pending amount will make user balance overpass maximum amount
            if ((userVePtpBalance + pending) > maxVePtpCap) {
                return maxVePtpCap - userVePtpBalance;
            } else {
                return pending;
            }
        }
        return 0;
    }

    /// @notice withdraws staked ptp
    /// @param _amount the amount of ptp to unstake
    /// Note Beware! you will loose all of your vePTP if you unstake any amount of ptp!
    function withdraw(uint256 _amount)
        external
        override
        nonReentrant
        whenNotPaused
    {
        require(_amount > 0, "amount to withdraw cannot be zero");
        require(users[msg.sender].amount >= _amount, "not enough balance");

        // reset last Release timestamp
        users[msg.sender].lastRelease = block.timestamp;

        // update his balance before burning or sending back ptp
        users[msg.sender].amount -= _amount;

        // get user vePTP balance that must be burned
        uint256 userVePtpBalance = balanceOf(msg.sender);

        _burn(msg.sender, userVePtpBalance);

        // send back the staked ptp
        ptp.safeTransfer(msg.sender, _amount);
    }

    /// @notice hook called after token operation mint/burn
    /// @dev updates masterPlatypus
    /// @param _account the account being affected
    /// @param _newBalance the newVePtpBalance of the user
    function _afterTokenOperation(address _account, uint256 _newBalance)
        internal
        override
    {
        masterPlatypus.updateFactor(_account, _newBalance);
    }

    /// @notice This function is called when users stake NFTs
    /// When Platypus NFT sent via safeTransferFrom(), we regard this action as staking the NFT
    /// Note that transferFrom() is ignored by this function
    function onERC721Received(
        address,
        address _from,
        uint256 _tokenId,
        bytes calldata
    ) external override nonReentrant whenNotPaused returns (bytes4) {
        require(
            msg.sender == address(nft),
            "only platypus NFT can be received"
        );
        require(isUser(_from), "user has no stake");

        // User has previously staked some NFT, try to unstake it first
        if (users[_from].stakedNftId != 0) {
            _unstakeNft(_from);
        }

        users[_from].stakedNftId = _tokenId + 1;

        emit StakedNft(_from, _tokenId);

        return ERC721_RECEIVED;
    }

    /// @notice unstakes current user nft
    function unstakeNft() external override nonReentrant whenNotPaused {
        _unstakeNft(msg.sender);
    }

    /// @notice private function used to unstake nft
    /// @param _addr the address of the nft owner
    function _unstakeNft(address _addr) private {
        uint256 stakedNftId = users[_addr].stakedNftId;
        require(stakedNftId > 0, "No NFT is staked");
        uint256 nftId = stakedNftId - 1;

        nft.safeTransferFrom(address(this), _addr, nftId, "");

        users[_addr].stakedNftId = 0;
        emit UnstakedNft(_addr, nftId);
    }

    /// @notice gets id of the staked nft
    /// @param _addr the addres of the nft staker
    /// @return id of the staked nft by _addr user
    /// if the user haven't stake any nft, tx reverts
    function getStakedNft(address _addr) external view returns (uint256) {
        uint256 stakedNftId = users[_addr].stakedNftId;
        require(stakedNftId > 0, "not staking");
        return stakedNftId - 1;
    }

    /// @notice get votes for vePTP
    /// @dev votes should only count if account has > threshold% of current cap reached
    /// @dev invVoteThreshold = (1/threshold%)*100
    /// @return the valid votes
    function getVotes(address _account)
        external
        view
        virtual
        override
        returns (uint256)
    {
        uint256 vePtpBalance = balanceOf(_account);

        // check that user has more than voting treshold of maxCap and has ptp in stake
        if (
            vePtpBalance * invVoteThreshold > users[_account].amount * maxCap &&
            isUser(_account)
        ) {
            return vePtpBalance;
        } else {
            return 0;
        }
    }
}