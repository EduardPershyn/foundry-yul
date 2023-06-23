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
                balanceOfBatch(decodeAsCdArray(0), decodeAsCdArray(1))
            }
            case 0x731133e9 /* "mint(address,uint256,uint256,bytes)" */ {
                mint(decodeAsAddress(0), decodeAsUint(1), decodeAsUint(2), decodeAsByteArray(3))
                returnEmpty()
            }
            case 0xf5298aca /* "burn(address, uint256, uint256)" */ {
                burn(decodeAsAddress(0), decodeAsUint(1), decodeAsUint(2))
                returnEmpty()
            }
            case 0xb48ab8b6 /* "batchMint(address,uint256[] memory,uint256[] memory,bytes memory)" */ {
                let ids, amounts := decodeTwoMemArrays(1, 2)
                batchMint(decodeAsAddress(0), ids, amounts, decodeAsByteArray(3))
                returnEmpty()
            }
            case 0xf6eb127a /* "batchBurn(address,uint256[] memory,uint256[] memory)" */ {
                let ids, amounts := decodeTwoMemArrays(1, 2)
                batchBurn(decodeAsAddress(0), ids, amounts)
                returnEmpty()
            }
            case 0xe985e9c5 /* "isApprovedForAll(address, address)" */ {
                returnUint(isApprovedForAll(decodeAsAddress(0), decodeAsAddress(1)))
            }
            case 0xa22cb465 /* "setApprovalForAll(address, bool)" */ {
                setApprovalForAll(decodeAsAddress(0), decodeAsUint(1))
                returnEmpty()
            }
            case 0xf242432a /* "safeTransferFrom(address, address, uint256, uint256, bytes calldata)" */ {
                safeTransferFrom(decodeAsAddress(0), decodeAsAddress(1), decodeAsUint(2), decodeAsUint(3), decodeAsByteArray(4))
                returnEmpty()
            }
            case 0x2eb2c2d6 /* "safeBatchTransferFrom(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)" */ {
                let ids, amounts := decodeTwoMemArrays(2, 3)
                safeBatchTransferFrom(decodeAsAddress(0), decodeAsAddress(1), ids, amounts, decodeAsByteArray(4))
                returnEmpty()
            }
            //case 0x0e89341c /* "uri(uint256 id)" */ {
            case 0x0623b787 /* "uriTest(uint256 id)" */ {
                uri(decodeAsUint(0))
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

                if iszero(eq(extcodesize(to), 0)) {
                    transferHook(caller(), 0x0, to, id, amount, data)
                }
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

                if iszero(eq(extcodesize(to), 0)) {
                    transferBatchHook(caller(), 0x0, to, ids, amounts, data)
                }
            }
            function batchBurn(from, ids, amounts) {
                require(iszero(eq(from, 0x00)))

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
            function isApprovedForAll(owner, operator) -> b {
                b := sload(isApprovedStorageOffset(owner, operator))
            }
            function setApprovalForAll(operator, approved) {
                sstore(isApprovedStorageOffset(caller(), operator), approved)

                emitApprovalForAll(caller(), operator, approved)
            }
            function safeTransferFrom(from, to, id, amount, data) {
                requireRecipient(iszero(eq(to, 0x00)))
                requireNotAuth(or( eq(caller(), from), isApprovedForAll(from, caller()) ))

                deductFromBalance(from, id, amount)
                addToBalance(to, id, amount)

                emitTransferSingle(caller(), from, to, id, amount)

                if iszero(eq(extcodesize(to), 0)) {
                    transferHook(caller(), from, to, id, amount, data)
                }
            }
            function safeBatchTransferFrom(from, to, ids, amounts, data) {
                requireRecipient(iszero(eq(to, 0x00)))
                requireNotAuth(or( eq(caller(), from), isApprovedForAll(from, caller()) ))

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
                    addToBalance(to, mload(idsPtr), mload(amountsPtr))
                }

                emitTransferBatch(caller(), from, to, ids, amounts)

                if iszero(eq(extcodesize(to), 0)) {
                    transferBatchHook(caller(), from, to, ids, amounts, data)
                }
            }
            function uri(id) {
                //cast --from-utf8 "ipfs://QmUzSR5yBqtsjnzfvfFZWe2JyEryhm7UgUfhKr9pkokG7C/"
                let mesPart1 := 0x697066733a2f2f516d557a53523579427174736a6e7a667666465a5765324a79
                let mesPart2 := 0x457279686d3755675566684b7239706b6f6b4737432f00000000000000000000

                let freeMPtr := mload(0x40)
                mstore(add(freeMPtr, 0x00), 0x20)
                //mstore(add(freeMPtr, 0x20), messageSize)
                mstore(add(freeMPtr, 0x40), mesPart1)
                mstore(add(freeMPtr, 0x60), mesPart2)

                //Converts hex representation of id to ASCII decimal, e.g. 0x539 -> 1337 -> 31 33 33 37
                function hexToDecRec(value, initLen, currentPtr) -> currentLen, newPtr {
                    currentLen := add(initLen, 1)
                    let temp := div(value, 10)
                    if temp {
                        currentLen, currentPtr := hexToDecRec(temp, currentLen, currentPtr)
                    }
                    mstore8(currentPtr, add(0x30, mod(value, 10)))
                    newPtr := add(currentPtr, 1)
                }
                let idLen, _ := hexToDecRec(id, 0, add(freeMPtr, 0x76))

                let messageSize := add(0x36, idLen)
                mstore(add(freeMPtr, 0x20), messageSize)


                // emit will revert if uri is view (executed from static context)
                emitUri(freeMPtr, add(messageSize, 0x40), id)

                return(freeMPtr, add(messageSize, 0x40))
            }

            /* ---------- transfer hooks ----------- */
            function transferHook(operator, from, to, id, amount, data) {
                //cast sig "onERC1155Received(address, address, uint256, uint256, bytes calldata)"
                //cast --to-bytes32 0xf23a6e61
                let rightPadSig := 0xf23a6e6100000000000000000000000000000000000000000000000000000000

                let freeMPtr := mload(0x40)

                mstore(freeMPtr, rightPadSig)
                mstore(add(freeMPtr, 0x04), operator)
                mstore(add(freeMPtr, 0x24), from)
                mstore(add(freeMPtr, 0x44), id)
                mstore(add(freeMPtr, 0x64), amount)
                mstore(add(freeMPtr, 0x84), 0xA0)  //data offset

                let bytes32Count := countBytes32(data)
                calldatacopy(add(freeMPtr, 0xA4), data, add( 0x20, mul(bytes32Count, 0x20) )) //copy data to memory

                mstore(0x00, 0x00) //clear first mem slot so return data be presize

                require(
                call(gas(),
                     to,
                     0,
                     freeMPtr,
                     add(0xC4, mul(bytes32Count, 0x20)),
                     0x1c,
                     4
                ))

                requireRecipient( eq(mload(0x00), 0xf23a6e61) )
            }
            function transferBatchHook(operator, from, to, ids, amounts, data) {
                //cast sig "onERC1155BatchReceived(address, address, uint256[], uint256[], bytes calldata)"
                //cast --to-bytes32 0xbc197c81
                let rightPadSig := 0xbc197c8100000000000000000000000000000000000000000000000000000000

                let freeMPtr := mload(0x40)

                mstore(freeMPtr, rightPadSig)
                mstore(add(freeMPtr, 0x04), operator)
                mstore(add(freeMPtr, 0x24), from)

                //Store first array
                let memPtr := add(freeMPtr, 0xA4)
                mstore(add(freeMPtr, 0x44), sub( sub(memPtr, 4), freeMPtr ))
                memPtr := copyMemArray(add(ids, mload(ids)), memPtr)

                //Store second array
                memPtr := add(memPtr, 0x20)
                mstore(add(freeMPtr, 0x64), sub( sub(memPtr, 4), freeMPtr ))
                memPtr := copyMemArray(add(amounts, mload(amounts)), memPtr)

                //Store byte array
                memPtr := add(memPtr, 0x20)
                mstore(add(freeMPtr, 0x84), sub( sub(memPtr, 4), freeMPtr ))

                let bytes32Count := countBytes32(data)
                let bytesDataLength := add( 0x20, mul(bytes32Count, 0x20) )
                calldatacopy( memPtr, data, bytesDataLength ) //copy data to memory

                mstore(0x00, 0x00) //clear first mem slot so return data be precise

                require(
                call(gas(),
                     to,
                     0,
                     freeMPtr,
                     add(sub(memPtr,freeMPtr), bytesDataLength),
                     0x1c,
                     4
                ))

                requireRecipient( eq(mload(0x00), 0xbc197c81) )
            }

            /* ---------- memory operations functions ----------- */
            function initMemArray(length) -> freeMPtr, arrayMemSize {
                freeMPtr := mload(0x40)
                mstore(freeMPtr, 0x20)                  //store array location in memory
                mstore(add(freeMPtr, 0x20), length)     //store array length

                arrayMemSize := add(0x40, mul(0x20, length))
                mstore(0x40, add(freeMPtr, arrayMemSize))         //update freeMemPtr
            }
            function copyMemArray(from, to) -> memPtr {
                let fromL := mload(from)
                mstore(to, fromL)
                for { let i := 0 } lt(i, fromL) { i := add(i, 1) }
                {
                    from := add(from, 0x20)
                    to := add(to, 0x20)
                    mstore(to, mload(from))
                }
                memPtr := to
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
            function decodeAsByteArray(offset) -> arrayPos {
                let parPos := add(4, mul(offset, 0x20))
                arrayPos := add(4, calldataload(parPos))
                let bytes32Count := countBytes32(arrayPos)

                if lt(calldatasize(), add(add(arrayPos, 0x20), mul(bytes32Count, 0x20))) {
                    revert(0, 0)
                }
            }
            function countBytes32(bytes) -> count {
                let dataLen := calldataload(bytes)
                count := div(dataLen, 0x20)
                if iszero( eq(mod(dataLen,0x20),0) )  {
                    count := add(count, 1)
                }
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
            function decodeTwoMemArrays(offset1, offset2) -> array1Pos, array2Pos {
                let arrayCdPos1 := decodeAsCdArray(offset1)
                let length1 := calldataload(arrayCdPos1)
                let arrayCdPos2 := decodeAsCdArray(offset2)
                let length2 := calldataload(arrayCdPos2)

                array1Pos := mload(0x40) //take freeMemPtr
                //store first array location in memory
                mstore(array1Pos, 0x40)
                //store second array location in memory
                let array2DataPos := add( 0x40, mul(length1, 0x20))
                array2Pos := add(array1Pos, 0x20)
                mstore(array2Pos, array2DataPos)

                let arraysMemSize := add(0x80, mul( 0x20, add(length1,length2) ))
                mstore(0x40, add(array1Pos, arraysMemSize))         //update freeMemPtr

                calldatacopy(add(array1Pos, 0x40), arrayCdPos1, add( 0x20, mul(0x20,length1) ))
                calldatacopy(add(array2Pos, array2DataPos), arrayCdPos2, add( 0x20, mul(0x20,length2) ))
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

                let amountsDataPos := mload(amounts)

                let idsL := mload( add(ids, mload(ids)) )
                let amountsL := mload( add(amounts, amountsDataPos) )
                let memSize := add( 0x80, mul( add(idsL, amountsL), 0x20 ) )

                mstore(amounts, add(amountsDataPos, 0x20) ) //make relative to first (ids) array
                log4(ids, memSize, signatureHash, operator, from, to)
                mstore(amounts, amountsDataPos) //restore memory
            }
            function emitApprovalForAll(owner, operator, approved) {
                // cast sig-event "ApprovalForAll(address indexed owner, address indexed operator, bool approved)"
                let signatureHash := 0x17307eab39ab6107e8899845ad3d59bd9653f200f220920489ca2b5937696c31

                mstore(0x00, approved)
                log3(0, 0x20, signatureHash, owner, operator)
            }
            function emitUri(valueMemStart, valueMemSize, id) {
                // cast sig-event "URI(string value, uint256 indexed id)"
                let signatureHash := 0x6bb7ff708619ba0610cba295a58592e0451dee2622938c8755667688daf3529b

                log2(valueMemStart, valueMemSize, signatureHash, id)
            }

            /* -------- storage layout ---------- */
            function balancePos() -> p { p := 0 }
            function isApprovedPos() -> p { p := 1 }
            function balanceStorageOffset(account, id) -> offset {
                mstore(0, account)
                mstore(0x20, balancePos())
                let key := keccak256(0, 0x40)

                mstore(0, id)
                mstore(0x20, key)
                offset := keccak256(0, 0x40)
            }
            function isApprovedStorageOffset(account, operator) -> offset {
                mstore(0, account)
                mstore(0x20, isApprovedPos())
                let key := keccak256(0, 0x40)

                mstore(0, operator)
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
            function requireNotAuth(condition) {
                if iszero(condition) {
                    //cast --from-utf8 "NOT_AUTHORIZED"
                    //cast --to-bytes32 0x4e4f545f415554484f52495a4544
                    let message := 0x4e4f545f415554484f52495a4544000000000000000000000000000000000000

                    mstore(0x00, 0x20)
                    mstore(0x20, 0x0E)
                    mstore(0x40, message)
                    revert(0x00, 0x60)
                }
            }
        }
    }
}