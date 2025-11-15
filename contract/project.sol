// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Project {
    
    struct LostItem {
        uint256 itemId;
        address owner;
        string itemDescription;
        string location;
        uint256 rewardAmount;
        bool isFound;
        bool isClaimed;
        address finder;
        uint256 timestamp;
    }
    
    struct User {
        uint256 itemsLost;
        uint256 itemsFound;
        uint256 reputationScore;
    }
    
    uint256 public itemCounter;
    mapping(uint256 => LostItem) public lostItems;
    mapping(address => User) public users;
    mapping(uint256 => bool) public activeItems;
    
    event ItemReported(
        uint256 indexed itemId,
        address indexed owner,
        string itemDescription,
        uint256 rewardAmount,
        uint256 timestamp
    );
    
    event ItemFound(
        uint256 indexed itemId,
        address indexed finder,
        uint256 timestamp
    );
    
    event RewardClaimed(
        uint256 indexed itemId,
        address indexed finder,
        uint256 rewardAmount,
        uint256 timestamp
    );
    
    event ItemCancelled(
        uint256 indexed itemId,
        address indexed owner,
        uint256 timestamp
    );
    
    modifier onlyItemOwner(uint256 _itemId) {
        require(lostItems[_itemId].owner == msg.sender, "Not the item owner");
        _;
    }
    
    modifier itemExists(uint256 _itemId) {
        require(_itemId > 0 && _itemId <= itemCounter, "Item does not exist");
        _;
    }
    
    modifier itemNotFound(uint256 _itemId) {
        require(!lostItems[_itemId].isFound, "Item already found");
        _;
    }
    
    // Core Function 1: Report a lost item
    function reportLostItem(
        string memory _itemDescription,
        string memory _location
    ) public payable returns (uint256) {
        require(bytes(_itemDescription).length > 0, "Description cannot be empty");
        require(msg.value > 0, "Reward amount must be greater than 0");
        
        itemCounter++;
        
        lostItems[itemCounter] = LostItem({
            itemId: itemCounter,
            owner: msg.sender,
            itemDescription: _itemDescription,
            location: _location,
            rewardAmount: msg.value,
            isFound: false,
            isClaimed: false,
            finder: address(0),
            timestamp: block.timestamp
        });
        
        activeItems[itemCounter] = true;
        users[msg.sender].itemsLost++;
        
        emit ItemReported(
            itemCounter,
            msg.sender,
            _itemDescription,
            msg.value,
            block.timestamp
        );
        
        return itemCounter;
    }
    
    // Core Function 2: Claim item as found
    function claimItemFound(
        uint256 _itemId,
        string memory _proofDescription
    ) public itemExists(_itemId) itemNotFound(_itemId) {
        require(activeItems[_itemId], "Item is not active");
        require(
            lostItems[_itemId].owner != msg.sender,
            "Owner cannot claim their own item"
        );
        require(bytes(_proofDescription).length > 0, "Proof description required");
        
        lostItems[_itemId].isFound = true;
        lostItems[_itemId].finder = msg.sender;
        
        emit ItemFound(_itemId, msg.sender, block.timestamp);
    }
    
    // Core Function 3: Confirm return and release reward
    function confirmReturnAndReleaseReward(uint256 _itemId)
        public
        itemExists(_itemId)
        onlyItemOwner(_itemId)
    {
        require(lostItems[_itemId].isFound, "Item not marked as found");
        require(!lostItems[_itemId].isClaimed, "Reward already claimed");
        require(lostItems[_itemId].finder != address(0), "No finder assigned");
        
        LostItem storage item = lostItems[_itemId];
        item.isClaimed = true;
        activeItems[_itemId] = false;
        
        address finder = item.finder;
        uint256 reward = item.rewardAmount;
        
        users[finder].itemsFound++;
        users[finder].reputationScore += 10;
        users[msg.sender].reputationScore += 5;
        
        (bool success, ) = payable(finder).call{value: reward}("");
        require(success, "Reward transfer failed");
        
        emit RewardClaimed(_itemId, finder, reward, block.timestamp);
    }
    
    // Additional Helper Function: Cancel lost item report
    function cancelLostItemReport(uint256 _itemId)
        public
        itemExists(_itemId)
        onlyItemOwner(_itemId)
        itemNotFound(_itemId)
    {
        require(activeItems[_itemId], "Item is not active");
        
        LostItem storage item = lostItems[_itemId];
        activeItems[_itemId] = false;
        
        uint256 refundAmount = item.rewardAmount;
        item.rewardAmount = 0;
        
        (bool success, ) = payable(msg.sender).call{value: refundAmount}("");
        require(success, "Refund transfer failed");
        
        emit ItemCancelled(_itemId, msg.sender, block.timestamp);
    }
    
    // View Functions
    function getItemDetails(uint256 _itemId)
        public
        view
        itemExists(_itemId)
        returns (
            address owner,
            string memory itemDescription,
            string memory location,
            uint256 rewardAmount,
            bool isFound,
            bool isClaimed,
            address finder,
            uint256 timestamp
        )
    {
        LostItem memory item = lostItems[_itemId];
        return (
            item.owner,
            item.itemDescription,
            item.location,
            item.rewardAmount,
            item.isFound,
            item.isClaimed,
            item.finder,
            item.timestamp
        );
    }
    
    function getUserReputation(address _user)
        public
        view
        returns (
            uint256 itemsLost,
            uint256 itemsFound,
            uint256 reputationScore
        )
    {
        User memory user = users[_user];
        return (user.itemsLost, user.itemsFound, user.reputationScore);
    }
    
    function isItemActive(uint256 _itemId) public view returns (bool) {
        return activeItems[_itemId];
    }
}
