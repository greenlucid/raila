import {
  Approval as ApprovalEvent,
  ApprovalForAll as ApprovalForAllEvent,
  LoanRepayment as LoanRepaymentEvent,
  RequestCanceled as RequestCanceledEvent,
  RequestCreation as RequestCreationEvent,
  Transfer as TransferEvent,
  Raila,
  Transfer,
} from "../generated/Raila/Raila";
import { Loan, Request } from "../generated/schema";

export function handleRequestCreation(event: RequestCreationEvent): void {
  let raila = Raila.bind(event.address);
  let request = new Request(event.params.requestId.toString());
  request.debtor = event.params.debtor;
  request.createdAtBlock = event.block.number;
  let thing = raila.requests(event.params.requestId);
  request.defaultThreshold = thing.getDefaultThreshold();
  request.status = "Open";

  request.save();
}

export function handleRequestCanceled(event: RequestCanceledEvent): void {
  let request = Request.load(event.params.requestId.toString());
  if (!request) return;
  request.status = "Canceled";

  request.save();
}

export function handleLoanRepayment(event: LoanRepaymentEvent): void {
  let loan = Loan.load(event.params.requestId.toString());
  if (!loan) return;
  loan.totalDebt = event.params.pendingDebt;
  loan.repaidAmount = event.params.repaidAmount;

  loan.save();
}

//? Evento transfer es usado para crear loans, para destruirlas y para cambiar el estado de creditor de un loan existente. Son tres funcionalidades completamente diferentes e independientes
// export function handleTransfer(event: TransferEvent): void {
//   if(event.params.from === 0){

//   }
//   else(event.params.to == 1){

//   }
  
//   let loan = Loan.load(event.params.tokenId.toString());
//   if (!loan) return;

//   loan.creditor = event.params.to;

//   loan.save();
// }
//! to fix

