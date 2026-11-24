@'
# Sn›spawn Resource Pack

Official resource pack for the Sn›spawn Minecraft server.

## Server Information

- Minecraft: 26.3 (target version)
- Server software: PaperMC
- Resource pack: Optional

## Download

Download snospawn.zip from the latest GitHub Release:

https://github.com/stephanteig/snospawn-resourcepack/releases/latest

## Publishing Updates

Run the publishing script from PowerShell:

    .\publish-resourcepack.ps1 -ZipPath "C:\path\to\pack.zip" -Version "1.0.1" -RedistributionApproved

Only publish assets you have permission to redistribute.
Verify Minecraft version compatibility before publishing.

Resource pack archives are hosted exclusively through GitHub Releases.

## Credits

Original archive: SNOSPAWN_by_MCTools.zip

All third-party assets belong to their respective creators.
Required credits must be added before publication.
'@ | Set-Content README.md -Encoding UTF8
