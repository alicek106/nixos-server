{ ... }:
{
  age.secrets = {
    nixos-credential.file = ./secrets/nixos-credential.age;
    aliced-env.file = ./secrets/aliced-env.age;
    slack-webhook = {
      file = ./secrets/slack-webhook.age;
      owner = "alicek106";
    };
  };
}
