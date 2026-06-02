import { IsString, IsOptional } from 'class-validator';

export class VerifyPurchaseDto {
  /** 'apple' or 'google' */
  @IsString()
  store!: string;

  /** Product ID (matches coin pack id, e.g. 'pack_299') */
  @IsString()
  productId!: string;

  /**
   * Apple: the transactionId from StoreKit 2 (JWS token or transaction ID string)
   * Google: the purchaseToken from Play Billing
   */
  @IsString()
  transactionId!: string;

  /**
   * Apple: the signed JWS transaction payload (from StoreKit 2 Transaction.jsonRepresentation)
   * Google: the purchaseToken (same as transactionId for Google)
   */
  @IsOptional()
  @IsString()
  receiptData?: string;
}
