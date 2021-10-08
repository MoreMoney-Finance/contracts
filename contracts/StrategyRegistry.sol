import "./RoleAware.sol";
import "../interfaces/IStrategy.sol";

contract StrategyRegistry is RoleAware {
    mapping(address => bool) public enabledStrategy;
    mapping(address => address) public replacementStrategy;

    constructor(address _roles) RoleAware(_roles) {

    }

    function enableStrategy(address strat) external onlyOwnerExec {
        enabledStrategy[strat] = true;
    }

    function disableStrategy(address strat) external onlyOwnerExec {
        enabledStrategy[strat] = false;
    }

    function replaceStrategy(address legacyStrat, address replacementStrat) external onlyOwnerExec {
        require(enabledStrategy[replacementStrat], "Replacement strategy is not enabled");
        IStrategy(legacyStrat).migrateAllTo(replacementStrat);
        enabledStrategy[legacyStrat] = false;
        replacementStrategy[legacyStrat] = replacementStrat;
    }

    function getCurrentStrategy(address strat) external view returns (address) {
        address result = strat;
        while (replacementStrategy[result] != address(0)) {
            result = replacementStrategy[result];
        }
        return result;
    }
}