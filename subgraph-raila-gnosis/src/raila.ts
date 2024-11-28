import {
  Approval as ApprovalEvent,
  ApprovalForAll as ApprovalForAllEvent,
  LoanRepayment as LoanRepaymentEvent,
  RequestCanceled as RequestCanceledEvent,
  RequestCreation as RequestCreationEvent,
  Transfer as TransferEvent
} from "../generated/Raila/Raila"
import {
  Approval,
  ApprovalForAll,
  LoanRepayment,
  RequestCanceled,
  RequestCreation,
  Transfer
} from "../generated/schema"

export function handleApproval(event: ApprovalEvent): void {
  let entity = new Approval(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.owner = event.params.owner
  entity.approved = event.params.approved
  entity.tokenId = event.params.tokenId

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleApprovalForAll(event: ApprovalForAllEvent): void {
  let entity = new ApprovalForAll(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.owner = event.params.owner
  entity.operator = event.params.operator
  entity.approved = event.params.approved

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleLoanRepayment(event: LoanRepaymentEvent): void {
  let entity = new LoanRepayment(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.requestId = event.params.requestId
  entity.repaidAmount = event.params.repaidAmount
  entity.pendingDebt = event.params.pendingDebt

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleRequestCanceled(event: RequestCanceledEvent): void {
  let entity = new RequestCanceled(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.requestId = event.params.requestId

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleRequestCreation(event: RequestCreationEvent): void {
  let entity = new RequestCreation(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.debtor = event.params.debtor
  entity.requestId = event.params.requestId
  entity.requestMetadata = event.params.requestMetadata

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleTransfer(event: TransferEvent): void {
  let entity = new Transfer(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.from = event.params.from
  entity.to = event.params.to
  entity.tokenId = event.params.tokenId

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}
