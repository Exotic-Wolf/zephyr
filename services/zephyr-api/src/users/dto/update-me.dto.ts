import {
  IsDateString,
  IsIn,
  IsOptional,
  IsString,
  IsUrl,
  MaxLength,
  MinLength,
  ValidateIf,
} from 'class-validator';

const GENDERS = ['Male', 'Female', 'Non-binary', 'Prefer not to say'] as const;

export class UpdateMeDto {
  @IsOptional()
  @IsString()
  @MinLength(2)
  @MaxLength(30)
  displayName?: string;

  @ValidateIf((_, value) => value !== null && value !== undefined)
  @IsUrl()
  avatarUrl?: string | null;

  @ValidateIf((_, value) => value !== null && value !== undefined)
  @IsString()
  @MaxLength(160)
  bio?: string | null;

  @ValidateIf((_, value) => value !== null && value !== undefined)
  @IsIn(GENDERS)
  gender?: string | null;

  @ValidateIf((_, value) => value !== null && value !== undefined)
  @IsDateString()
  birthday?: string | null;

  @ValidateIf((_, value) => value !== null && value !== undefined)
  @IsString()
  @MaxLength(2)
  countryCode?: string | null;

  @ValidateIf((_, value) => value !== null && value !== undefined)
  @IsString()
  @MaxLength(50)
  language?: string | null;
}