import { IsString, MinLength } from 'class-validator';

export class LoginDto {
  // The field keeps the `email` API name for backwards compatibility, but it
  // accepts the configured local demo username as well.
  @IsString()
  @MinLength(1)
  email!: string;

  @IsString()
  @MinLength(1)
  password!: string;
}
