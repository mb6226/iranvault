# Push local project to VPS and run deploy script
scp -i C:\iranvault\setup\deployer_id_ed25519 -r C:\iranvault\* deployer@171.22.174.195:/opt/iranvault/
ssh -i C:\iranvault\setup\deployer_id_ed25519 deployer@171.22.174.195 'cd /opt/iranvault && chmod +x deploy.sh && ./deploy.sh'
