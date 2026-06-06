import {
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

export class SendGiftDto {
  @IsUUID()
  sessionId!: string;

  @IsString()
  giftId!: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(100)
  quantity?: number;

  @IsOptional()
  @IsString()
  @MinLength(8)
  @MaxLength(160)
  idempotencyKey?: string;
}
