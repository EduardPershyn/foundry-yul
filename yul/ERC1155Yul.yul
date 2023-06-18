object "ERC1155Yul" {
    code {
        datacopy(0, dataoffset("Runtime"), datasize("Runtime"))
        return(0, datasize("Runtime"))
    }
    object "Runtime" {
        // Return the calldata
        code {
            require(iszero(callvalue()))

            mstore(0x40, 0x80) //init free memory pointer

            // Dispatcher
            switch selector()
            case 0x00fdd58e /* "balanceOf(address, uint256)" */ {
                returnUint(balanceOf(decodeAsAddress(0), decodeAsUint(1)))
            }
            case 0x4e1273f4 /* "balanceOfBatch(address[] calldata, uint256[] calldata)" */ {
                //returnArray(balanceOfBatch(decodeAsCdArray(0), decodeAsCdArray(1)))
                balanceOfBatch(decodeAsCdArray(0), decodeAsCdArray(1))
            }
            case 0x731133e9 /* "mint(address,uint256,uint256,bytes)" */ {
                mint(decodeAsAddress(0), decodeAsUint(1), decodeAsUint(2), decodeAsUint(3))
                returnEmpty()
            }
            case 0xf5298aca /* "burn(address, uint256, uint256)" */ {
                burn(decodeAsAddress(0), decodeAsUint(1), decodeAsUint(2))
                returnEmpty()
            }
            case 0xb48ab8b6 /* "batchMint(address,uint256[] memory,uint256[] memory,bytes memory)" */ {
                batchMint(decodeAsAddress(0), decodeAsMemArray(1), decodeAsMemArray(2), decodeAsUint(3))
                returnEmpty()
            }
            case 0xf6eb127a /* "batchBurn(address,uint256[] memory,uint256[] memory)" */ {
                batchBurn(decodeAsAddress(0), decodeAsMemArray(1), decodeAsMemArray(2))
                returnEmpty()
            }
            default {
                revert(0, 0)
            }

            function balanceOf(account, id) -> bal {
                bal := sload(balanceStorageOffset(account, id))
            }
            function balanceOfBatch(owners, ids) {
                let ownersL := calldataload(owners)
                let idsL := calldataload(ids)

                requireLength(eq(ownersL, idsL))

                let arrayMemStart, arrayMemSize := initMemArray(ownersL)

                let balancePtr := add(arrayMemStart, 0x20)
                let ownerPtr := owners
                let idsPtr := ids
                for { let i := 0 } lt(i, ownersL) { i := add(i, 1) }
                {
                    balancePtr := add(balancePtr, 0x20)
                    ownerPtr := add(ownerPtr, 0x20)
                    idsPtr := add(idsPtr, 0x20)
                    mstore(
                        balancePtr,
                        balanceOf(calldataload(ownerPtr), calldataload(idsPtr))
                    )
                }
                return(arrayMemStart, arrayMemSize)
            }
            function mint(to, id, amount, data) {
                requireRecipient(iszero(eq(to, 0x00)))

                addToBalance(to, id, amount)

                emitTransferSingle(caller(), 0x0, to, id, amount)
            }
            function burn(from, id, amount) {
                deductFromBalance(from, id, amount)

                emitTransferSingle(caller(), from, 0x0, id, amount)
            }
            function batchMint(to, ids, amounts, data) {
                requireRecipient(iszero(eq(to, 0x00)))

                let idsPtr := add(ids, mload(ids))
                let amountsPtr := add(amounts, mload(amounts))

                let idsL := mload(idsPtr)
                let amountsL := mload(amountsPtr)
                requireLength(eq(amountsL, idsL))

                for { let i := 0 } lt(i, idsL) { i := add(i, 1) }
                {
                    idsPtr := add(idsPtr, 0x20)
                    amountsPtr := add(amountsPtr, 0x20)
                    addToBalance(to, mload(idsPtr), mload(amountsPtr))
                }

                emitTransferBatch(caller(), 0x0, to, ids, amounts)
            }
            function batchBurn(from, ids, amounts) {
                requireRecipient(iszero(eq(from, 0x00)))

                let idsPtr := add(ids, mload(ids))
                let amountsPtr := add(amounts, mload(amounts))

                let idsL := mload(idsPtr)
                let amountsL := mload(amountsPtr)
                requireLength(eq(amountsL, idsL))

                for { let i := 0 } lt(i, idsL) { i := add(i, 1) }
                {
                    idsPtr := add(idsPtr, 0x20)
                    amountsPtr := add(amountsPtr, 0x20)
                    deductFromBalance(from, mload(idsPtr), mload(amountsPtr))
                }

                emitTransferBatch(caller(), from, 0x0, ids, amounts)
            }

            /* ---------- memory operations functions ----------- */
            function initMemArray(length) -> freeMPtr, arrayMemSize {
                freeMPtr := mload(0x40)
                mstore(freeMPtr, 0x20)                  //store array location in memory
                mstore(add(freeMPtr, 0x20), length)     //store array length

                arrayMemSize := add(0x40, mul(0x20, length))
                mstore(0x40, add(freeMPtr, arrayMemSize))         //update freeMemPtr
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
            function decodeAsCdArray(offset) -> arrayPos {
                let parPos := add(4, mul(offset, 0x20))
                arrayPos := add(4, calldataload(parPos))
                let length := calldataload(arrayPos)

                if lt(calldatasize(), add(add(arrayPos, 0x20), mul(length, 0x20))) {
                    revert(0, 0)
                }
            }
            function decodeAsMemArray(offset) -> arrayMemPos {
                let arrayCdPos := decodeAsCdArray(offset)
                let length := calldataload(arrayCdPos)

                let arrayMemStart, arrayMemSize := initMemArray(length)
                calldatacopy(add(arrayMemStart, 0x20), arrayCdPos, arrayMemSize)

                arrayMemPos := arrayMemStart
            }

            /* ---------- calldata encoding functions ---------- */
            function returnUint(v) {
                mstore(0, v)
                return(0, 0x20)
            }
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
            function emitTransferBatch(operator, from, to, ids, amounts) {
                // cast sig-event "TransferBatch(address indexed,address indexed,address indexed,uint256[],uint256[])"
                let signatureHash := 0x4a39dc06d4c0dbc64b70af90fd698a233a518aa5d07e595d983b8c0526c8f7fb

                // Assume arrays are already coupled in memory
                let idsPtr := add(ids, 0x20)
                let amountsPtr := add(amounts, 0x20)
                let idsL := mload(idsPtr)
                let amountsL := mload(amountsPtr)

                let size := add( 0x80, mul( add(idsL, amountsL), 0x20 ) )
                if lt(ids, amounts) {
                    log4(ids, size, signatureHash, operator, from, to)
                }
                if lt(amounts, ids) {
                    log4(amounts, size, signatureHash, operator, from, to)
                }
            }

            /* -------- storage layout ---------- */
            function balancePos() -> p { p := 0 }
            function balanceStorageOffset(account, id) -> offset {
                mstore(0, account)
                mstore(0x20, balancePos())
                let key := keccak256(0, 0x40)

                mstore(0, id)
                mstore(0x20, key)
                offset := keccak256(0, 0x40)
            }

            /* -------- storage access ---------- */
            function addToBalance(to, id, amount) {
                let offset := balanceStorageOffset(to, id)
                sstore(offset, safeAdd(sload(offset), amount))
            }
            function deductFromBalance(from, id, amount) {
                let offset := balanceStorageOffset(from, id)
                let bal := sload(offset)
                require(lte(amount, bal))
                sstore(offset, sub(bal, amount))
            }

            /* ---------- utility functions ---------- */
            function lte(a, b) -> r {
                r := iszero(gt(a, b))
            }
            function safeAdd(a, b) -> r {
                r := add(a, b)
                if or(lt(r, a), lt(r, b)) { revert(0, 0) }
            }

            /* ---------- revert functions ---------- */
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
            function requireLength(condition) {
                if iszero(condition) {
                    //cast --from-utf8 "UNSAFE_RECIPIENT"
                    //cast --to-bytes32 0x4c454e4754485f4d49534d41544348
                    let message := 0x4c454e4754485f4d49534d415443480000000000000000000000000000000000

                    mstore(0x00, 0x20)
                    mstore(0x20, 0x0F)
                    mstore(0x40, message)
                    revert(0x00, 0x60)
                }
            }
        }
    }
}