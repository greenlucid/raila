import { newMockEvent } from "matchstick-as"
import { ethereum, Address, BigInt, Bytes } from "@graphprotocol/graph-ts"
import {
  Approval,
  ApprovalForAll,
  LoanForgiven,
  LoanRepayment,
  RequestCanceled,
  RequestCreation,
  Transfer
} from "../generated/Raila/Raila"

export function createApprovalEvent(
  owner: Address,
  approved: Address,
  tokenId: BigInt
): Approval {
  let approvalEvent = changetype<Approval>(newMockEvent())

  approvalEvent.parameters = new Array()

  approvalEvent.parameters.push(
    new ethereum.EventParam("owner", ethereum.Value.fromAddress(owner))
  )
  approvalEvent.parameters.push(
    new ethereum.EventParam("approved", ethereum.Value.fromAddress(approved))
  )
  approvalEvent.parameters.push(
    new ethereum.EventParam(
      "tokenId",
      ethereum.Value.fromUnsignedBigInt(tokenId)
    )
  )

  return approvalEvent
}

export function createApprovalForAllEvent(
  owner: Address,
  operator: Address,
  approved: boolean
): ApprovalForAll {
  let approvalForAllEvent = changetype<ApprovalForAll>(newMockEvent())

  approvalForAllEvent.parameters = new Array()

  approvalForAllEvent.parameters.push(
    new ethereum.EventParam("owner", ethereum.Value.fromAddress(owner))
  )
  approvalForAllEvent.parameters.push(
    new ethereum.EventParam("operator", ethereum.Value.fromAddress(operator))
  )
  approvalForAllEvent.parameters.push(
    new ethereum.EventParam("approved", ethereum.Value.fromBoolean(approved))
  )

  return approvalForAllEvent
}

export function createLoanForgivenEvent(
  requestId: BigInt,
  pendingDebt: BigInt
): LoanForgiven {
  let loanForgivenEvent = changetype<LoanForgiven>(newMockEvent())

  loanForgivenEvent.parameters = new Array()

  loanForgivenEvent.parameters.push(
    new ethereum.EventParam(
      "requestId",
      ethereum.Value.fromUnsignedBigInt(requestId)
    )
  )
  loanForgivenEvent.parameters.push(
    new ethereum.EventParam(
      "pendingDebt",
      ethereum.Value.fromUnsignedBigInt(pendingDebt)
    )
  )

  return loanForgivenEvent
}

export function createLoanRepaymentEvent(
  requestId: BigInt,
  repaidAmount: BigInt,
  pendingDebt: BigInt
): LoanRepayment {
  let loanRepaymentEvent = changetype<LoanRepayment>(newMockEvent())

  loanRepaymentEvent.parameters = new Array()

  loanRepaymentEvent.parameters.push(
    new ethereum.EventParam(
      "requestId",
      ethereum.Value.fromUnsignedBigInt(requestId)
    )
  )
  loanRepaymentEvent.parameters.push(
    new ethereum.EventParam(
      "repaidAmount",
      ethereum.Value.fromUnsignedBigInt(repaidAmount)
    )
  )
  loanRepaymentEvent.parameters.push(
    new ethereum.EventParam(
      "pendingDebt",
      ethereum.Value.fromUnsignedBigInt(pendingDebt)
    )
  )

  return loanRepaymentEvent
}

export function createRequestCanceledEvent(requestId: BigInt): RequestCanceled {
  let requestCanceledEvent = changetype<RequestCanceled>(newMockEvent())

  requestCanceledEvent.parameters = new Array()

  requestCanceledEvent.parameters.push(
    new ethereum.EventParam(
      "requestId",
      ethereum.Value.fromUnsignedBigInt(requestId)
    )
  )

  return requestCanceledEvent
}

export function createRequestCreationEvent(
  debtor: Bytes,
  requestId: BigInt,
  requestMetadata: string
): RequestCreation {
  let requestCreationEvent = changetype<RequestCreation>(newMockEvent())

  requestCreationEvent.parameters = new Array()

  requestCreationEvent.parameters.push(
    new ethereum.EventParam("debtor", ethereum.Value.fromFixedBytes(debtor))
  )
  requestCreationEvent.parameters.push(
    new ethereum.EventParam(
      "requestId",
      ethereum.Value.fromUnsignedBigInt(requestId)
    )
  )
  requestCreationEvent.parameters.push(
    new ethereum.EventParam(
      "requestMetadata",
      ethereum.Value.fromString(requestMetadata)
    )
  )

  return requestCreationEvent
}

export function createTransferEvent(
  from: Address,
  to: Address,
  tokenId: BigInt
): Transfer {
  let transferEvent = changetype<Transfer>(newMockEvent())

  transferEvent.parameters = new Array()

  transferEvent.parameters.push(
    new ethereum.EventParam("from", ethereum.Value.fromAddress(from))
  )
  transferEvent.parameters.push(
    new ethereum.EventParam("to", ethereum.Value.fromAddress(to))
  )
  transferEvent.parameters.push(
    new ethereum.EventParam(
      "tokenId",
      ethereum.Value.fromUnsignedBigInt(tokenId)
    )
  )

  return transferEvent
}
