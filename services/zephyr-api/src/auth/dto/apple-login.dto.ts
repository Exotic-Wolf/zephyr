import { IsOptional, IsString } from 'class-validator';

export class AppleLoginDto {
  @IsString()
  idToken!: string;

  @IsOptional()
  @IsString()
  givenName?: string;

  @IsOptional()
  @IsString()
  familyName?: string;

  @IsOptional()
  @IsString()
  email?: string;
}