// SPDX-License-Identifier: MIT

/*
                                                 .
        .-=-:    ..:  .:::::::  ::::::---:     -##++*+*.::----:  -==-   ---.--::---=.
      =#=-=+=+#=@+=+%##=#@=--%+##=@*-=##==#=-*#==*#= :%@*-:**+=#*@-=@%-+@:@@+-:+**=#=
     =%..%@@@--@@+.-@=+@@@@=.:%%-@@*::@@+.+@@::*@@@#=.#@#::@@%..@@=.:*@@@.@@#. %=-+=
     =@-..*@@@@@@*:::.*@@@@@+..-@@@#:.#*-:*@@.-@@@@%=:=@#:.*=:+%@@=+=.:%@:@@#..%*++:
      *@*-..-+@@@+.-@=.-%@@@@.:#@@@*:-@@@=.*@-.+*@@@:.+@#.:@%::#@@=*@#:.*:@@#..=+=%-
     -#*@@%=-:.%@*.-@@#-.:=#%==++@@*..#%#:=%@%-.:--.:#@@*..@@@-.-#+*@@@-..@@%..#+:.
     +*.@@@@#..#@=::@@@@%*+=--=+%@@@@@@@@@@@@@@@%##%@@@@@%%@@@@%=-::--#@*.@@%..*+..:
      %*=+*+:=*@@@@@@@@%#%##****##**+++*###+##*###**+++**#*****#%##@@@@@@@@@@#*+**+%+
       -#@@@@@@@@@@%%%%%%#*++**%%#++++*#%*******#%#*+++*#%%#*++*#%%%#%%@@@@@@@@@@@%#
     :+***+++***@@@%###*****#@@#**#@@@@%**#@@#***#****#@@@@%**+**#%@@###%@@@@%#******%+
   .#*-:::---:::%@@@-:--====:@@@-::=@@@@=:#@@@-:=+++++-@@%-:=+++--=@@#::@@@#=::----::-@
  :@+::=#@@@@@%*+@@@-:*@@@@@@%@@--=--%@@=-+@@@-:#@@@@%@@@+--%@@@@@+@@%::@@%-:=@@@@@%#=%-
  %*::+@@@@%%%%%#%@@=--====-@@@@--##-:#@=-*@@%--:::::=@@@@+-::-=+#@@@#-:@@%--:=+*#%@@@%*
 .@+--*@@@@------%@@=-+**#**@@@@=-%@%=-+=-*@@@=-#%%%%#@@@#@@%##*=--%@#-:@@@@*+=---::-+@-
 .@#---@@@%%@@+--@@@=-*@@@@@%%@%=-%@@@+-==*@@@==+*###**#@*-*#%@@%=-+@#--@@*%@@@@@%#+---@
  +@+--=#@@@@%+=-@@@==------=%@%==*@@@@*+++@@%+*+++++++@@@++=---==*@@#=-@@%-=*#%@%%*=-=@:
   *@#+==----====%@%##%%%%%@@@@@@%%%#*#####**##*#########%##@@@@@@#%@%#*#@@*===---===*@*
    :*@%##**##%@%#=+==--::..                                  ..    :-==+=%@@@%%%%%@%*-
       :-=++=-:                                                            .  .:--:.
*/

pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "../../../thirdparty/falkor-contracts/utils/vrf/IVRFSubcriber.sol";
import "../../../thirdparty/falkor-contracts/utils/vrf/IVRFKeeper.sol";

import "../interfaces/IERC721ASafeMintable.sol";

import { ERC721SeaDropUpgradeable } from "../../../thirdparty/opensea/seadrop-upgradeable/src/ERC721SeaDropUpgradeable.sol";
import { ERC721AUpgradeable } from "../../../thirdparty/opensea/seadrop-upgradeable/lib/erc721a-upgradeable/contracts/ERC721AUpgradeable.sol";
import { COLLECTION_ADMIN_ROLE } from "../../WLRoleConstants.sol";

contract NexianGems is
	Initializable,
	ERC721SeaDropUpgradeable,
	AccessControlUpgradeable,
	UUPSUpgradeable,
	IVRFSubcriber
{
	// ====================================================
	// ERRORS
	// ====================================================
	error Unauthorized();
	error AlreadyRevealed();
	error NotFullyMinted();
	error InvalidToken();

	// ====================================================
	// STATE
	// ====================================================
	IERC721ASafeMintable public immortalsContract;
	IVRFKeeper public vrfKeeperContract;

	/// @notice See {ERC721SeaDropRandomOffset}
	uint256 public constant _FALSE = 1;
	uint256 public constant _TRUE = 2;

	uint256 public revealed;
	uint256 public randomOffset;

	// ====================================================
	// CONSTRUCTOR / INITIALIZER
	// ====================================================
	/// @custom:oz-upgrades-unsafe-allow constructor
	constructor() {
		_disableInitializers();
	}

	function initialize(
		string memory name_,
		string memory symbol_,
		address[] memory allowedSeaDrop_
	) external initializer initializerERC721A {
		ERC721SeaDropUpgradeable.__ERC721SeaDrop_init(name_, symbol_, allowedSeaDrop_);

		__AccessControl_init();
		__UUPSUpgradeable_init();

		_setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
		_setRoleAdmin(COLLECTION_ADMIN_ROLE, DEFAULT_ADMIN_ROLE);

		revealed = _FALSE;
	}

	// ====================================================
	// OVERRIDES
	// ====================================================
	function supportsInterface(
		bytes4 interfaceId
	) public view override(AccessControlUpgradeable, ERC721SeaDropUpgradeable) returns (bool) {
		return
			AccessControlUpgradeable.supportsInterface(interfaceId) ||
			ERC721SeaDropUpgradeable.supportsInterface(interfaceId) ||
			super.supportsInterface(interfaceId);
	}

	function _authorizeUpgrade(address newImplementation) internal virtual override onlyRole(COLLECTION_ADMIN_ROLE) {}

	function _beforeTokenTransfers(
		address _from,
		address _to,
		uint256 _startTokenId,
		uint256 _quantity
	) internal virtual override(ERC721AUpgradeable) {
		super._beforeTokenTransfers(_from, _to, _startTokenId, _quantity);
	}

	// ====================================================
	// INTERNAL
	// ====================================================
	function _vrfCallback(uint256 /*requestId*/, uint256[] memory randomWords) external {
		if (msg.sender != address(vrfKeeperContract)) {
			revert Unauthorized();
		}

		if (revealed == _TRUE) {
			revert AlreadyRevealed();
		}

		randomOffset = (randomWords[0] % (maxSupply() - 1)) + 1;
		revealed = _TRUE;
	}

	// ====================================================
	// ROLE GATED
	// ====================================================
	function setContracts(
		IERC721ASafeMintable immContract,
		IVRFKeeper keeperContract
	) public onlyRole(COLLECTION_ADMIN_ROLE) {
		immortalsContract = immContract;
		vrfKeeperContract = keeperContract;
	}

	function setRandomOffset() external onlyRole(COLLECTION_ADMIN_ROLE) {
		if (revealed == _TRUE) {
			revert AlreadyRevealed();
		}

		if (_totalMinted() != maxSupply()) {
			revert NotFullyMinted();
		}

		vrfKeeperContract.requestRandomness(1, this);
	}

	function setRevealedStatus(bool status) public onlyRole(COLLECTION_ADMIN_ROLE) {
		if (status) {
			if (totalSupply() != maxSupply()) {
				revert NotFullyMinted();
			}
			revealed = _TRUE;
		} else revealed = _FALSE;
	}

	// ====================================================
	// PUBLIC API
	// ====================================================
	function mintSeaDrop(address minter, uint256 quantity) external override nonReentrant {
		// Ensure the SeaDrop is allowed.
		_onlyAllowedSeaDrop(msg.sender);

		// Extra safety check to ensure the max supply is not exceeded.
		if (_totalMinted() + quantity > maxSupply()) {
			revert MintQuantityExceedsMaxSupply(_totalMinted() + quantity, maxSupply());
		}

		// Mint the quantity of tokens to the minter.
		_safeMint(minter, quantity);

		// mint immortals
		if (address(immortalsContract) != address(0)) {
			immortalsContract.safeMint(minter, quantity * 3);
		}
	}

	function tokenURI(uint256 tokenId) public view override returns (string memory) {
		if (!_exists(tokenId)) {
			revert InvalidToken();
		}

		if (revealed == _FALSE) {
			return super.tokenURI(tokenId);
		}
		uint256 id = ((tokenId + randomOffset) % maxSupply()) + _startTokenId();
		return super.tokenURI(id);
	}

	function startTokenId() public view returns (uint256) {
		return super._startTokenId();
	}
}
