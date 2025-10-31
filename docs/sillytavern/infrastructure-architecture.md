# SillyTavern Infrastructure Architecture Roadmap

## Executive Summary

This document outlines the SillyTavern deployment architecture across our home lab infrastructure, detailing the migration from legacy systems to a modern, containerized, declarative NixOS-based environment. The goal is to establish a scalable, maintainable, and reproducible SillyTavern deployment while preserving data integrity and user experience continuity.

## Current Infrastructure Landscape

### Production Environment (MVP - Current Active System)
- **Platform**: Unraid server (Hydra)
- **Container Runtime**: Docker
- **Data Storage**: SMB share (`smb://hydra/appdata/STConfig/Data`)
- **Network Access**: HTTPS on dedicated port
- **Status**: Production active, serving users
- **Data Volume**: Significant user-generated content (characters, chats, configurations)

### Legacy Environment (Deprecated)
- **Platform**: Arch Linux with CachyOS kernel
- **Container Runtime**: Docker (user-space)
- **Data Location**: `/run/media/warby/86d37145-405a-48ac-bd33-73f85e8ecaf9/@home/warby/Workspace` (fuzzy match folders with "silly")
- **Storage**: ~1TB legacy partition
- **Status**: Deprecated, data preserved for migration
- **Characteristics**: Complex data structure with 40+ AI model configurations, extensive chat histories, custom themes, and third-party extensions

### Next Generation Environment (Target Architecture)
- **Platform**: NixOS (Cerberus system)
- **Container Runtime**: Podman (rootless, daemonless)
- **Configuration Management**: Declarative NixOS modules
- **Data Location**: `/home/warby/appdata/silly/Data/default-user` (current) → `/var/lib/sillytavern` (target system-managed)
- **Workspace**: `/home/warby/Workspace` (development) → `Silly/` (project files)
- **Storage**: 4TB NVMe workspace
- **Status**: Development target, future production
- **Goals**: Reproducibility, security, scalability

## Architecture Components

### Data Architecture

#### User Data Structure (Mapped from Legacy System)
```
Data/default-user/
├── settings.json                 # Core user preferences
├── characters/                   # Character definitions
├── chats/                        # Conversation histories (per character)
├── group chats/                  # Multi-user conversations
├── groups/                       # Group definitions
├── worlds/                       # Lorebooks and world information
├── backgrounds/                  # UI background images
├── themes/                       # Custom UI themes
├── User Avatars/                 # User profile images
├── thumbnails/                   # Cached image thumbnails
├── context/                      # 40+ AI model configurations
├── instruct/                     # Instruction templates
├── sysprompt/                    # System prompt templates
├── extensions/                   # Third-party extensions
├── user/
│   ├── workflows/               # ComfyUI integration workflows
│   ├── files/                   # User-uploaded files
│   └── images/                  # User-uploaded images
├── KoboldAI Settings/           # Backend-specific configs
├── NovelAI Settings/
├── OpenAI Settings/
├── TextGen Settings/
├── movingUI/                    # UI layout configurations
├── QuickReplies/                # Quick reply templates
├── vectors/                     # Vector database data
├── assets/                      # Additional assets
├── reasoning/                   # Reasoning configurations
└── backups/                     # Historical backups
```

#### Data Migration Strategy
- **Source**: Legacy Arch system (`/home/warby/appdata/silly/Data/default-user`)
- **Target**: NixOS system (`/var/lib/sillytavern/data`)
- **Method**: Rsync with integrity verification
- **Retention**: 7-year backup policy for production data
- **Validation**: File count, size, and hash comparisons

### Container Architecture

#### Current Production (Docker on Unraid)
```yaml
# docker-compose.yml (inferred)
version: '3.8'
services:
  sillytavern:
    image: ghcr.io/sillytavern/sillytavern:latest
    ports:
      - "8443:8000"  # HTTPS port
    volumes:
      - /mnt/user/appdata/STConfig:/home/node/app/data
    environment:
      - NODE_ENV=production
    restart: unless-stopped
```

#### Target Architecture (Podman on NixOS)
```nix
# virtualisation.oci-containers.containers.sillytavern
{
  image = "ghcr.io/sillytavern/sillytavern:latest";
  ports = [ "0.0.0.0:8000:8000" ];
  volumes = [
    "/var/lib/sillytavern/data:/home/node/app/data"
    "/var/lib/sillytavern/config:/home/node/app/config"
  ];
  environment = {
    NODE_ENV = "production";
  };
  user = "sillytavern:sillytavern";
  autoStart = true;
}
```

### Network Architecture

#### Current Production
- **Access Method**: HTTPS (SSL termination at reverse proxy level)
- **Port**: Dedicated service port (8443)
- **Authentication**: Application-level (whitelist in config.yaml)
- **Network**: Local network access

#### Target Architecture
- **Access Method**: HTTP (with optional Caddy reverse proxy for HTTPS)
- **Port**: 8000 (configurable)
- **Authentication**: Application-level whitelist
- **Network**: Configurable (localhost-only or network-wide)
- **Firewall**: Declarative NixOS firewall rules

### Security Architecture

#### Container Security
- **Rootless Operation**: Podman runs containers as unprivileged user
- **User Namespacing**: UID/GID mapping for file permissions
- **Capability Dropping**: Minimal Linux capabilities
- **Seccomp**: System call restrictions (future enhancement)

#### Data Security
- **File Permissions**: Strict ownership (sillytavern:sillytavern)
- **Backup Encryption**: Consideration for sensitive data
- **Access Control**: System-level user isolation

## Migration Roadmap

### Phase 1: Infrastructure Preparation (Current)
- [x] Analyze existing data structures
- [x] Document current infrastructure
- [x] Create NixOS module for SillyTavern
- [x] Set up Podman configuration
- [ ] Build and test SillyTavern package

### Phase 2: Data Migration
- [ ] Create backup of production data
- [ ] Set up test migration environment
- [ ] Execute data transfer with integrity checks
- [ ] Validate data completeness

### Phase 3: Service Deployment
- [ ] Deploy containerized SillyTavern on NixOS
- [ ] Configure networking and firewall
- [ ] Test service functionality
- [ ] Validate user experience parity

### Phase 4: Production Cutover
- [ ] Establish sync mechanism with production
- [ ] Perform final data synchronization
- [ ] Update DNS/network configuration
- [ ] Monitor post-migration stability

### Phase 5: Optimization and Scaling
- [ ] Implement monitoring and alerting
- [ ] Set up automated backups
- [ ] Document operational procedures
- [ ] Plan for future scaling needs

## Risk Assessment

### Critical Risks
1. **Data Loss**: Migration could corrupt or lose user data
   - Mitigation: Multiple backup copies, integrity validation
2. **Service Interruption**: Users unable to access during cutover
   - Mitigation: Maintain production system during testing
3. **Configuration Incompatibility**: Container differences affect functionality
   - Mitigation: Thorough testing, gradual rollout

### Technical Risks
1. **Podman vs Docker Differences**: Subtle runtime differences
   - Mitigation: Test all features, document workarounds
2. **NixOS Declarative Complexity**: Learning curve for management
   - Mitigation: Comprehensive documentation, training
3. **Storage Performance**: NVMe vs NFS performance characteristics
   - Mitigation: Benchmarking, optimization

## Success Criteria

### Functional Requirements
- [ ] All user data successfully migrated
- [ ] All chat histories accessible
- [ ] All character configurations preserved
- [ ] All extensions and workflows functional
- [ ] Network access equivalent to production

### Non-Functional Requirements
- [ ] Service startup time < 30 seconds
- [ ] Memory usage within acceptable limits
- [ ] Backup completion < 1 hour
- [ ] Zero data loss during migration

## Future Considerations

### Scalability
- **Horizontal Scaling**: Multiple SillyTavern instances
- **Load Balancing**: Distribute user load
- **Database Separation**: External database for chat storage

### High Availability
- **Redundancy**: Multiple server deployment
- **Automated Failover**: Service continuity
- **Geographic Distribution**: Multi-location access

### Integration
- **API Gateway**: Centralized access management
- **Monitoring Stack**: Comprehensive observability
- **CI/CD Pipeline**: Automated deployment updates

## Conclusion

This architecture roadmap provides a structured approach to migrating SillyTavern from legacy Docker/Unraid deployment to a modern Podman/NixOS environment. The focus on data integrity, security, and maintainability ensures a reliable foundation for future growth and scaling of our home lab infrastructure.

The declarative nature of NixOS combined with Podman's security features creates a robust platform for containerized applications, while the comprehensive data mapping ensures no user-generated content is lost in the transition.