import { IsInt, IsOptional, IsString, IsUUID, Max, Min } from 'class-validator';

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
}
