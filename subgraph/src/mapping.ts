import { Address, BigInt } from "@graphprotocol/graph-ts";
import {
  Raila,
  LoanForgiven,
  LoanRepayment,
  RequestCanceled,
  RequestCreation,
  Transfer,
} from "../generated/Raila/Raila";
import { Request, Loan } from "../generated/schema";
const NULL_ADDRESS = Address.fromString(
  "0x0000000000000000000000000000000000000000"
);

export function handleRequestCreation(event: RequestCreation): void {
  let raila = Raila.bind(event.address);
  let request = new Request(event.params.requestId.toString());
  request.debtor = event.params.debtor;
  request.createdAtBlock = event.block.number;
  let requestInContract = raila.requests(event.params.requestId);
  request.defaultThreshold = requestInContract.getDefaultThreshold();
  request.metadata = event.params.requestMetadata;
  request.amount = requestInContract.getOriginalDebt();
  request.save();
  // request.status = "Open";
}

export function handleRequestCanceled(event: RequestCanceled): void {
  let request = Request.load(event.params.requestId.toString()) as Request;
  request.canceledAt = event.block.timestamp;
  request.save();
}

export function handleTransfer(event: Transfer): void {
  if (event.params.from === NULL_ADDRESS && event.params.to !== NULL_ADDRESS) {
    // Loan Created
    let loan = new Loan(event.params.tokenId.toString());
    let request = Request.load(event.params.tokenId.toString()) as Request;
    let raila = Raila.bind(event.address);

    loan.request = request.id;
    loan.creditor = raila.requests(event.params.tokenId).getCreditor();
    loan.fundedAt = raila.requests(event.params.tokenId).getFundedAt();
    loan.lastUpdatedAt = raila
      .requests(event.params.tokenId)
      .getLastUpdatedAt();
    loan.feeRate = raila.requests(event.params.tokenId).getFeeRate();
    loan.originalDebt = raila.requests(event.params.tokenId).getOriginalDebt();
    loan.totalDebt = raila.requests(event.params.tokenId).getTotalDebt();
    loan.repaidAmount = BigInt.fromU32(0);
    loan.save();
  } else if (
    event.params.from !== NULL_ADDRESS &&
    event.params.to === NULL_ADDRESS
  ) {
    // Loan Destroyed
    let loan = Loan.load(event.params.tokenId.toString()) as Loan;
    loan.destroyedAt = event.block.timestamp;
    loan.save();
  } else {
    // Regular Loan Transfer
    let loan = Loan.load(event.params.tokenId.toString()) as Loan;
    loan.creditor = event.params.to;
    loan.save();
  }
}

export function handleLoanForgiven(event: LoanForgiven): void {
  let loan = Loan.load(event.params.requestId.toString()) as Loan;
  loan.destroyedAt = event.block.timestamp;
  loan.save();
}

export function handleLoanRepayment(event: LoanRepayment): void {
  let raila = Raila.bind(event.address);
  let loan = Loan.load(event.params.requestId.toString()) as Loan;
  loan.repaidAmount = loan.repaidAmount.plus(event.params.repaidAmount);
  let requestInContract = raila.requests(event.params.requestId);
  // could not be updated if below MIN_PERIOD, so grab from contract
  loan.originalDebt = requestInContract.getOriginalDebt();
  loan.totalDebt = requestInContract.getTotalDebt();
  let lastUpdatedAt = requestInContract.getLastUpdatedAt();
  // note, this can be zero if destroyed. overwrite with current time if so.
  loan.lastUpdatedAt = lastUpdatedAt.equals(BigInt.fromU32(0))
    ? event.block.timestamp
    : lastUpdatedAt; 
}
