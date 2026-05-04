import { IsString } from 'class-validator';

export class PurchaseCoinsDto {
  @IsString()
  packId!: string;
}
