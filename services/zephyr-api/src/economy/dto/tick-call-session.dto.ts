import {
  IsInt,
  IsOptional,
  IsString,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

export class TickCallSessionDto {
  @IsOptional()
  @IsInt()
  @Min(1)
  elapsedSeconds?: number;

  @IsOptional()
  @IsString()
  @MinLength(8)
  @MaxLength(160)
  idempotencyKey?: string;
}
