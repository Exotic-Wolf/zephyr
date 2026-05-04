import { IsIn, IsInt, IsOptional, IsUUID, Min } from 'class-validator';

export class StartCallSessionDto {
  @IsIn(['direct', 'random'])
  mode!: 'direct' | 'random';

  @IsOptional()
  @IsUUID()
  receiverUserId?: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  directRateCoinsPerMinute?: number;
}
