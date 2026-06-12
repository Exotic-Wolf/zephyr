import {
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

const GIFT_SURFACES = [
  'inbox',
  'direct_call',
  'random_call',
  'live_room',
  'premium_live',
  'premium_live_entry',
] as const;

export class SendGiftDto {
  @IsOptional()
  @IsIn(GIFT_SURFACES)
  surface?: (typeof GIFT_SURFACES)[number];

  @IsOptional()
  @IsString()
  @MaxLength(180)
  contextId?: string;

  @IsOptional()
  @IsUUID()
  sessionId?: string;

  @IsOptional()
  @IsUUID()
  receiverUserId?: string;

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
