# 📚 W365 Spoke Network - Documentation Index

Welcome to the Windows 365 Spoke Network deployment package! This index will help you find the right documentation for your needs.

## 🚀 Getting Started (Pick One)

| If you want to... | Read this file |
|-------------------|---------------|
| **Deploy as quickly as possible** | [QUICKSTART.md](./QUICKSTART.md) |
| **Understand what this deploys** | [README.md](./README.md) |
| **See the full deployment guide** | [Deployps1-Readme.md](./Deployps1-Readme.md) |
| **Compare with Hub deployment** | [HUB-VS-SPOKE.md](./HUB-VS-SPOKE.md) |
| **View network architecture** | [ARCHITECTURE-DIAGRAM.md](./ARCHITECTURE-DIAGRAM.md) |
| **Get a complete overview** | [DEPLOYMENT-SUMMARY.md](./DEPLOYMENT-SUMMARY.md) |

## 📖 Documentation Guide

### For First-Time Deployers

**Start here**: 
1. [README.md](./README.md) - Understand what you're deploying
2. [QUICKSTART.md](./QUICKSTART.md) - Quick prerequisites and commands
3. Run `.\deploy.ps1 -Validate`

### For Production Deployments

**Recommended reading order**:
1. [Deployps1-Readme.md](./Deployps1-Readme.md) - Complete guide
2. [ARCHITECTURE-DIAGRAM.md](./ARCHITECTURE-DIAGRAM.md) - Network design
3. [HUB-VS-SPOKE.md](./HUB-VS-SPOKE.md) - Integration with hub
4. Review and customize `infra/envs/prod/parameters.prod.json`
5. Run `.\deploy.ps1 -Validate`
6. Run `.\deploy.ps1`

### For Troubleshooting

**Go directly to**:
- [Deployps1-Readme.md](./Deployps1-Readme.md) - Troubleshooting section
  - Location format errors
  - Permission errors
  - VNet peering issues
  - Address space conflicts

### For Architecture Understanding

**Read**:
- [ARCHITECTURE-DIAGRAM.md](./ARCHITECTURE-DIAGRAM.md) - Visual diagrams
- [HUB-VS-SPOKE.md](./HUB-VS-SPOKE.md) - Hub-spoke topology
- [DEPLOYMENT-SUMMARY.md](./DEPLOYMENT-SUMMARY.md) - Complete overview

## 📄 File Descriptions

### Documentation Files

| File | Purpose | Length | Read Time |
|------|---------|--------|-----------|
| **QUICKSTART.md** | Fast start guide | Short | 2-3 min |
| **README.md** | Project overview | Medium | 5-7 min |
| **Deployps1-Readme.md** | Complete deployment guide | Long | 15-20 min |
| **HUB-VS-SPOKE.md** | Architecture comparison | Long | 10-15 min |
| **ARCHITECTURE-DIAGRAM.md** | Visual network diagrams | Medium | 5-10 min |
| **DEPLOYMENT-SUMMARY.md** | Comprehensive summary | Long | 10-15 min |
| **INDEX.md** | This file | Short | 2 min |

### Code Files

| File | Purpose | Type |
|------|---------|------|
| **deploy.ps1** | PowerShell deployment script | PowerShell |
| **infra/envs/prod/main.bicep** | Main orchestration template | Bicep |
| **infra/envs/prod/parameters.prod.json** | Configuration values | JSON |
| **infra/modules/rg/main.bicep** | Resource group module | Bicep |
| **infra/modules/spoke-network/main.bicep** | Network module | Bicep |

## 🎯 Quick Reference by Task

### Task: "I need to deploy this NOW"
→ [QUICKSTART.md](./QUICKSTART.md)

### Task: "What permissions do I need?"
→ [Deployps1-Readme.md](./Deployps1-Readme.md#prerequisites) - Section 2

### Task: "How do I connect to the hub?"
→ [HUB-VS-SPOKE.md](./HUB-VS-SPOKE.md#hub-spoke-integration)

### Task: "What IP addresses are used?"
→ [ARCHITECTURE-DIAGRAM.md](./ARCHITECTURE-DIAGRAM.md#-ip-address-allocation)

### Task: "Deployment failed with error X"
→ [Deployps1-Readme.md](./Deployps1-Readme.md#-troubleshooting)

### Task: "How much will this cost?"
→ [HUB-VS-SPOKE.md](./HUB-VS-SPOKE.md#-cost-comparison)

### Task: "What security controls are included?"
→ [ARCHITECTURE-DIAGRAM.md](./ARCHITECTURE-DIAGRAM.md#-network-security-group-rules)

### Task: "How do I customize the address space?"
→ [Deployps1-Readme.md](./Deployps1-Readme.md#customize-address-space)

### Task: "What's different from the hub deployment?"
→ [HUB-VS-SPOKE.md](./HUB-VS-SPOKE.md#-key-differences)

### Task: "What happens after deployment?"
→ [DEPLOYMENT-SUMMARY.md](./DEPLOYMENT-SUMMARY.md#-next-steps-after-deployment)

## 🔍 Documentation Features

### In QUICKSTART.md
- ✅ Prerequisites checklist
- ✅ 3-step deployment process
- ✅ Expected output
- ✅ Common issues
- ✅ Next steps

### In README.md
- ✅ Project overview
- ✅ What's included
- ✅ IP allocation table
- ✅ Configuration examples
- ✅ Security features
- ✅ Folder structure

### In Deployps1-Readme.md (Most Comprehensive)
- ✅ Complete deployment guide
- ✅ Prerequisites with install commands
- ✅ Permission requirements (detailed)
- ✅ Usage examples
- ✅ Configuration options
- ✅ Deployment process (6 steps)
- ✅ Troubleshooting (5 common errors)
- ✅ Security considerations
- ✅ Pre-deployment checklist
- ✅ Next steps guide

### In HUB-VS-SPOKE.md
- ✅ Architecture comparison table
- ✅ Permission differences
- ✅ When to use each
- ✅ Integration steps
- ✅ IP address planning
- ✅ Cost comparison
- ✅ Best practices
- ✅ Migration scenarios

### In ARCHITECTURE-DIAGRAM.md
- ✅ Network topology diagram
- ✅ IP address allocation chart
- ✅ NSG rules visualization
- ✅ Hub-spoke peering diagram
- ✅ Traffic flow diagrams
- ✅ Resource hierarchy
- ✅ Deployment flow chart

### In DEPLOYMENT-SUMMARY.md
- ✅ Complete file structure
- ✅ Infrastructure summary
- ✅ Permission requirements
- ✅ Deployment instructions
- ✅ All documentation descriptions
- ✅ Key features list
- ✅ Configuration options
- ✅ Validation checklist
- ✅ Comparison with hub
- ✅ Success criteria

## 📋 Pre-Deployment Checklist

Before you start, ensure you have:

- [ ] Read at least [QUICKSTART.md](./QUICKSTART.md) or [README.md](./README.md)
- [ ] Azure PowerShell installed
- [ ] Bicep CLI installed
- [ ] Azure login completed
- [ ] Contributor or Network Contributor permissions
- [ ] Reviewed `parameters.prod.json`
- [ ] Run `.\deploy.ps1 -Validate`

## 🎓 Learning Path

### Beginner (Just getting started)
1. Start with [QUICKSTART.md](./QUICKSTART.md)
2. Run `.\deploy.ps1 -Validate`
3. If errors, check [Deployps1-Readme.md](./Deployps1-Readme.md#-troubleshooting)

### Intermediate (Production deployment)
1. Read [README.md](./README.md)
2. Read [Deployps1-Readme.md](./Deployps1-Readme.md)
3. Review [ARCHITECTURE-DIAGRAM.md](./ARCHITECTURE-DIAGRAM.md)
4. Customize `parameters.prod.json`
5. Run `.\deploy.ps1 -Validate` then `.\deploy.ps1`

### Advanced (Hub integration)
1. Read [HUB-VS-SPOKE.md](./HUB-VS-SPOKE.md)
2. Deploy hub network first (if not done)
3. Get hub VNet ID
4. Update `parameters.prod.json` with hub VNet ID
5. Run `.\deploy.ps1`
6. Create reverse peering from hub

## 💡 Tips for Success

1. **Always validate first**: Never skip `.\deploy.ps1 -Validate`
2. **Read error messages**: They often point to the exact fix needed
3. **Check permissions early**: Run the permission check commands
4. **Use What-If**: Preview changes with `.\deploy.ps1 -WhatIf`
5. **Document changes**: Keep notes on customizations
6. **Test in dev first**: Don't deploy directly to production

## 🆘 Getting Help

### Step 1: Check Documentation
- Error during deployment? → [Deployps1-Readme.md](./Deployps1-Readme.md#-troubleshooting)
- Don't understand architecture? → [ARCHITECTURE-DIAGRAM.md](./ARCHITECTURE-DIAGRAM.md)
- Need to compare with hub? → [HUB-VS-SPOKE.md](./HUB-VS-SPOKE.md)

### Step 2: Common Issues
1. **Permission Error**: See [Deployps1-Readme.md](./Deployps1-Readme.md#2-insufficient-permissions)
2. **Location Error**: See [Deployps1-Readme.md](./Deployps1-Readme.md#1-location-format-error)
3. **Peering Error**: See [Deployps1-Readme.md](./Deployps1-Readme.md#4-vnet-peering-failed)

### Step 3: Azure Resources
- Check Azure Portal → Deployments for detailed error logs
- Review Network Watcher for connectivity issues
- Check Activity Log for permission denials

## 🔄 Version Information

**Current Version**: 1.0
**Last Updated**: October 2, 2025
**Bicep Version**: 0.38.3+
**PowerShell Version**: 5.1+

## 📞 Support Resources

- **Microsoft Docs**: [Hub-spoke network topology](https://learn.microsoft.com/azure/architecture/reference-architectures/hybrid-networking/hub-spoke)
- **Windows 365 Docs**: [Network requirements](https://learn.microsoft.com/windows-365/enterprise/requirements-network)
- **Bicep Docs**: [Bicep language reference](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)

---

**Ready to start?** Begin with [QUICKSTART.md](./QUICKSTART.md) → `.\deploy.ps1 -Validate` → `.\deploy.ps1` 🚀
