import { IsInt, IsOptional, Min } from 'class-validator';

export class TickCallSessionDto {
  @IsOptional()
  @IsInt()
  @Min(1)
  elapsedSeconds?: number;
}
