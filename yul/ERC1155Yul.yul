object "ERC1155Yul" {
    code {
        datacopy(0, dataoffset("Runtime"), datasize("Runtime"))
        return(0, datasize("Runtime"))
    }
    object "Runtime" {
        // Return the calldata
        code {
            require(iszero(callvalue()))

            // Dispatcher
            switch selector()
            case 0x731133e9 /* "mint(address,uint256,uint256,bytes)" */ {
                mint(decodeAsAddress(0), decodeAsUint(1), decodeAsUint(2), decodeAsUint(3))
                returnEmpty()
            }
            default {
                revert(0, 0)
            }

            function mint(to, id, amount, data) {
                requireRecipient(iszero(eq(to, 0x00)))

                addToBalance(to, id, amount)
                emitTransferSingle(caller(), 0x0, to, id, amount)
            }

            /* ---------- calldata decoding functions ----------- */
            function selector() -> s {
                s := shr(0xE0, calldataload(0))
            }
            function decodeAsAddress(offset) -> v {
                v := decodeAsUint(offset)
                if and(v, not(0xffffffffffffffffffffffffffffffffffffffff)) {
                    revert(0, 0)
                }
            }
            function decodeAsUint(offset) -> v {
                let pos := add(4, mul(offset, 0x20))
                if lt(calldatasize(), add(pos, 0x20)) {
                    revert(0, 0)
                }
                v := calldataload(pos)
            }

            /* ---------- calldata encoding functions ---------- */
            function returnEmpty() {
                return(0, 0)
            }

            /* -------- events ---------- */
            function emitTransferSingle(operator, from, to, id, amount) {
                // cast sig-event "TransferSingle(address indexed,address indexed,address indexed,uint256,uint256)"
                let signatureHash := 0xc3d58168c5ae7397731d063d5bbf3d657854427343f4c083240f7aacaa2d0f62

                mstore(0x00, id)
                mstore(0x20, amount)
                log4(0, 0x40, signatureHash, operator, from, to)
            }

            /* -------- storage layout ---------- */
            function balancePos() -> p { p := 0 }
            function balanceToStorageOffset(account, id) -> offset {
                mstore(0, account)
                mstore(0x20, balancePos())
                let key := keccak256(0, 0x40)

                mstore(0, id)
                mstore(0x20, key)
                offset := keccak256(0, 0x40)
            }

            /* -------- storage access ---------- */
            function addToBalance(to, id, amount) {
                let offset := balanceToStorageOffset(to, id)
                sstore(offset, safeAdd(sload(offset), amount))
            }

            /* ---------- utility functions ---------- */
            function safeAdd(a, b) -> r {
                r := add(a, b)
                if or(lt(r, a), lt(r, b)) { revert(0, 0) }
            }
            function require(condition) {
                if iszero(condition) { revert(0, 0) }
            }
            function requireRecipient(condition) {
                if iszero(condition) {
                    //cast --from-utf8 "UNSAFE_RECIPIENT"
                    //cast --to-bytes32 0x554e534146455f524543495049454e54
                    let message := 0x554e534146455f524543495049454e5400000000000000000000000000000000

                    mstore(0x00, 0x20)
                    mstore(0x20, 0x10)
                    mstore(0x40, message)
                    revert(0x00, 0x60)
                }
            }
        }
    }
}