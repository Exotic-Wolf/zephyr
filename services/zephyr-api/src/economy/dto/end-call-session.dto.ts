import { IsOptional, IsString } from 'class-validator';

export class EndCallSessionDto {
  @IsOptional()
  @IsString()
  reason?: string;
}
