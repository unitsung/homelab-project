import Foundation

// MARK: - Translations struct (maps 1:1 to constants/translations.ts)

struct Translations {
    // Common
    let loading: String
    let error: String
    let refresh: String
    let cancel: String
    let save: String
    let confirm: String
    let delete: String
    let back: String
    let close: String
    let copy: String
    let yes: String
    let no: String
    let noData: String
    let retry: String
    let notAvailable: String
    let reconnect: String
    let offlineUnreachable: String

    // Tabs
    let tabHome: String
    let tabBookmarks: String
    let tabSettings: String
    let tabMedia: String

    // Launcher
    let launcherTitle: String
    let launcherSubtitle: String
    let launcherConnected: String
    let launcherNotConfigured: String
    let launcherTapToConnect: String
    let launcherServices: String
    let homeReorderServices: String
    let overviewEmptyTitle: String
    let overviewEmptyMessage: String
    let overviewStripGuidance: String
    let overviewCpuLabel: String
    let overviewMemoryLabel: String
    let overviewContainersLabel: String

    // Tailscale
    let tailscaleConnect: String
    let tailscaleDesc: String

    // Status
    let statusUnreachable: String
    let statusVerifying: String
    let statusOnline: String
    let actionReconnect: String

    // Greetings
    let greetingMorning: String
    let greetingAfternoon: String
    let greetingEvening: String
    let summaryTitle: String
    let summaryQueryTotal: String
    let summarySystemsOnline: String

    // Services
    let servicePortainer: String
    let servicePihole: String
    let serviceAdguard: String
    let serviceBeszel: String
    let serviceHealthchecks: String
    let serviceGitea: String
    let serviceNpm: String
    let servicePatchmon: String
    let serviceJellystat: String
    let servicePortainerDesc: String
    let servicePiholeDesc: String
    let serviceAdguardDesc: String
    let serviceBeszelDesc: String
    let serviceHealthchecksDesc: String
    let serviceGiteaDesc: String
    let serviceNpmDesc: String
    let servicePatchmonDesc: String
    let serviceJellystatDesc: String
    let serviceTechnitiumDesc: String
    let serviceLinuxUpdateDesc: String
    let serviceDockhandDesc: String
    let serviceDockmonDesc: String
    let serviceKomodoDesc: String
    let serviceMaltrailDesc: String
    let serviceUptimeKumaDesc: String
    let servicePangolinDesc: String
    let pangolinSitesClientsLabel: String
    let servicePlex: String
    let serviceRadarr: String
    let serviceSonarr: String
    let serviceLidarr: String
    let serviceQbittorrent: String
    let serviceJellyseerr: String
    let serviceProwlarr: String
    let serviceBazarr: String
    let serviceGluetun: String
    let serviceFlaresolverr: String
    let serviceWakapi: String
    let servicePlexDesc: String
    let serviceRadarrDesc: String
    let serviceSonarrDesc: String
    let serviceLidarrDesc: String
    let serviceQbittorrentDesc: String
    let serviceJellyseerrDesc: String
    let serviceProwlarrDesc: String
    let serviceBazarrDesc: String
    let serviceGluetunDesc: String
    let serviceFlaresolverrDesc: String
    let serviceWakapiDesc: String
    let serviceCraftyControllerDesc: String
    let serviceUnifiNetworkDesc: String
    let loginHintUnifiNetwork: String
    let unifiAuthMode: String
    let unifiSiteManager: String
    let unifiLocalNetwork: String
    let unifiSiteManagerHelp: String
    let unifiLocalNetworkHelp: String
    let unifiSiteManagerURLPlaceholder: String
    let unifiSection: String
    let unifiDevices: String
    let unifiClients: String
    let unifiSites: String
    let unifiHosts: String
    let unifiOnlineDevices: String
    let unifiOfflineDevices: String
    let unifiWifiClients: String
    let unifiWiredClients: String
    let unifiInternetHealth: String
    let unifiLatency: String
    let unifiPacketLoss: String
    let unifiUptime: String
    let unifiTime: String
    let unifiNeedsAttention: String
    let unifiNoClients: String
    let unifiGuestAuthorizedFormat: String
    let unifiUnauthorizedGuestsFormat: String
    let unifiOpenDemo: String
    let unifiDemoInfo: String
    let unifiGuestAuthorizationFailed: String
    let unifiAllSites: String
    let unifiSiteDistribution: String
    let unifiTrafficNow: String
    let unifiNetworks: String
    let unifiViewAll: String
    let unifiDownload: String
    let unifiUpload: String
    let unifiThroughput: String
    let unifiPorts: String
    let unifiVlan: String
    let unifiSubnet: String
    let unifiDhcp: String
    let unifiUsage: String
    let unifiAll: String
    let unifiAPs: String
    let unifiSwitches: String
    let unifiGateways: String
    let unifiGuest: String
    let unifiPendingUpdatesFormat: String
    let unifiCriticalAlertsFormat: String
    let unifiSearchDevices: String
    let unifiSearchClients: String
    let unifiDeviceDetail: String
    let unifiDeviceHealth: String
    let unifiTemperature: String
    let unifiClientDetail: String
    let unifiGuestUnauthorized: String
    let unifiWifiRadios: String
    let unifiQuality: String
    let unifiSignal: String
    let unifiClientExperience: String
    let unifiOperations: String
    let unifiWan: String
    let unifiLan: String
    let unifiTopology: String
    let unifiFabric: String
    let unifiCoverage: String
    let unifiUplinks: String

    // Login
    let loginTitle: String
    let loginSubtitle: String
    let loginUrlOnlySubtitle: String
    let loginUrl: String
    let loginUrlPlaceholder: String
    let loginUsername: String
    let loginEmail: String
    let loginPassword: String
    let loginTokenKey: String
    let loginTokenSecret: String
    let loginConnect: String
    let loginConnecting: String
    let loginErrorUrl: String
    let loginErrorCredentials: String
    let loginErrorFailed: String
    let loginHintPihole: String
    let loginHintAdguard: String
    let loginHintGitea2FA: String
    let loginHintPortainer: String
    let loginHintTechnitium: String
    let loginHintLinuxUpdate: String
    let loginHintDockhand: String
    let loginHintDockmon: String
    let loginHintKomodo: String
    let loginHintMaltrail: String
    let loginHintUptimeKuma: String
    let loginHintHealthchecks: String
    let loginHintPatchmon: String
    let loginHintJellystat: String
    let loginHintPlex: String
    let loginHintPangolin: String
    let loginPangolinOrgIdPlaceholder: String
    let loginHintGluetun: String
    let loginHintFlaresolverr: String
    let loginHintWakapi: String
    let loginHintCraftyController: String
    let loginOptional2FA: String
    let loginApiKey: String
    let done: String

    // Portainer
    let portainerDashboard: String
    let portainerEndpoints: String
    let portainerActive: String
    let portainerContainers: String
    let portainerResources: String
    let portainerTotal: String
    let portainerRunning: String
    let portainerStopped: String
    let portainerImages: String
    let portainerVolumes: String
    let portainerCpus: String
    let portainerMemory: String
    let portainerViewAll: String
    let portainerSelectEndpoint: String
    let portainerServerInfo: String
    let portainerOnline: String
    let portainerOffline: String
    let portainerStacks: String
    let portainerHealthy: String
    let portainerUnhealthy: String
    let portainerHealthStatus: String
    let portainerHost: String

    // Containers
    let containersSearch: String
    let containersAll: String
    let containersRunning: String
    let containersStopped: String
    let containersEmpty: String
    let containersNoEndpoint: String

    // Actions
    let actionStart: String
    let actionStop: String
    let actionRestart: String
    let actionBackup: String
    let actionPause: String
    let actionResume: String
    let actionKill: String
    let actionRemove: String
    let actionClear: String
    let actionConfirm: String
    let actionConfirmMessage: String
    let actionRemoveConfirm: String
    let actionRemoveMessage: String

    // Container detail
    let detailInfo: String
    let detailStats: String
    let detailLogs: String
    let detailEnv: String
    let detailCompose: String
    let detailContainer: String
    let detailId: String
    let detailCreated: String
    let detailHostname: String
    let detailWorkDir: String
    let detailCommand: String
    let detailNetwork: String
    let detailMode: String
    let detailMounts: String
    let detailRestartPolicy: String
    let detailPolicy: String
    let detailMaxRetries: String
    let detailUptime: String
    let detailNotRunning: String
    let detailNoLogs: String
    let detailEnvVars: String
    let detailCpu: String
    let detailMemory: String
    let detailNetworkIO: String
    let detailRx: String
    let detailTx: String
    let detailUsed: String
    let detailContainerLogs: String
    let detailNotFound: String
    let detailComposeFile: String
    let detailComposeNotAvailable: String
    let detailComposeSave: String
    let detailComposeSaved: String
    let detailComposeSaveError: String
    let detailComposeLoading: String

    // Dockhand
    let dockhandEnvironments: String
    let dockhandIssues: String
    let dockhandNoContainers: String
    let dockhandStacks: String
    let dockhandNoStacks: String
    let dockhandResources: String
    let dockhandImages: String
    let dockhandVolumes: String
    let dockhandNetworks: String
    let dockhandActivity: String
    let dockhandSchedules: String
    let dockhandDisabled: String
    let dockhandState: String
    let dockhandStatus: String
    let dockhandPorts: String
    let dockhandHealth: String
    let dockhandLogs: String
    let dockhandNoLogs: String
    let dockhandSettingsTitle: String
    let dockhandSettingsRefresh: String
    let dockhandSettingsData: String
    let dockhandAutoRefresh: String
    let dockhandRefreshInterval: String
    let dockhandActivityLimit: String
    let dockhandShowAdvancedActivity: String
    let dockhandLiveStats: String
    let dockhandShowLess: String
    let dockhandMoreLines: String
    let dockhandPlatform: String
    let dockhandRuntime: String
    let dockhandDriver: String
    let dockhandEntrypoint: String
    let dockhandServicesLabel: String
    let dockhandSource: String
    let dockhandSourceType: String
    let dockhandNextRun: String
    let dockhandLastRun: String
    let dockhandDescription: String
    let dockhandEntity: String
    let dockhandSystemLabel: String
    let dockhandEnabledLabel: String
    let dockhandRecentRuns: String

    // DockMon
    let dockmonHosts: String
    let dockmonAllHosts: String
    let dockmonContainers: String
    let dockmonAutoRestart: String
    let dockmonUpdates: String
    let dockmonUpdateAvailable: String
    let dockmonNoHosts: String
    let dockmonNoContainers: String
    let dockmonOpenLogs: String
    let dockmonRestartContainer: String
    let dockmonUpdateContainer: String
    let dockmonImagePlaceholder: String
    let dockmonCurrentImage: String
    let dockmonLatestImage: String
    let dockmonHost: String
    let dockmonActionSuccess: String
    let dockmonErrorInvalidCredentials: String

    // Komodo
    let komodoApiSecret: String
    let komodoResources: String
    let komodoContainers: String
    let komodoContainerStates: String
    let komodoServers: String
    let komodoDeployments: String
    let komodoStacks: String
    let komodoVersion: String
    let komodoHealthy: String
    let komodoUnhealthy: String
    let komodoPaused: String
    let komodoRestarting: String
    let komodoUnknown: String
    let komodoOpenStacks: String
    let komodoStackManagement: String
    let komodoStackManagementSubtitle: String
    let komodoNoStacks: String
    let komodoStackServices: String
    let komodoNoStackServices: String
    let komodoDeploy: String
    let komodoStart: String
    let komodoStop: String
    let komodoRestart: String
    let komodoUpdateAvailable: String
    let komodoErrorInvalidCredentials: String

    // Maltrail
    let maltrailFindings: String
    let maltrailLatestDay: String
    let maltrailTotalFindings: String
    let maltrailDailyCounts: String
    let maltrailEvents: String
    let maltrailNoCounts: String
    let maltrailNoEvents: String
    let maltrailSelectedDate: String
    let maltrailSource: String
    let maltrailDestination: String
    let maltrailTrail: String
    let maltrailSensor: String
    let maltrailProtocol: String
    let maltrailSeverity: String
    let maltrailEventDetails: String

    // Uptime Kuma
    let uptimeKumaMonitors: String
    let uptimeKumaUp: String
    let uptimeKumaDown: String
    let uptimeKumaPending: String
    let uptimeKumaMaintenance: String
    let uptimeKumaUnknown: String
    let uptimeKumaAvgLatency: String
    let uptimeKumaCertExpiring: String
    let uptimeKumaResponseTime: String
    let uptimeKumaCertDays: String
    let uptimeKumaNoMonitors: String
    let uptimeKumaInvalidMetrics: String

    // Linux Update
    let linuxUpdateActionCheckAll: String
    let linuxUpdateActionRefreshCache: String
    let linuxUpdateActionCheck: String
    let linuxUpdateActionUpgrade: String
    let linuxUpdateActionFullUpgrade: String
    let linuxUpdateActionPackageUpgrade: String
    let linuxUpdateAvailableUpdates: String
    let linuxUpdateHiddenUpdates: String
    let linuxUpdateNoHiddenUpdates: String
    let linuxUpdateKeptBack: String
    let linuxUpdateHidden: String

    // Technitium
    let technitiumUpdateBlockLists: String
    let technitiumDisableBlocking: String
    let technitiumBlockDomain: String
    let technitiumDisableFor5Minutes: String
    let technitiumDisableFor30Minutes: String
    let technitiumDisableUntilManual: String
    let technitiumCustomDisableTimer: String
    let technitiumCustomDisableDescription: String
    let technitiumMinutes: String
    let technitiumBlockDomainDescription: String
    let technitiumRange: String
    let technitiumDnsBlocking: String
    let technitiumEnabled: String
    let technitiumDisabled: String
    let technitiumDisabledUntil: String
    let technitiumBlockedQueries: String
    let technitiumBlockedZones: String
    let technitiumNoClients: String
    let technitiumNoDomains: String
    let technitiumNoBlockedDomains: String
    let technitiumZones: String
    let technitiumCacheEntries: String
    let technitiumBlocklistZones: String
    let technitiumVersion: String
    let technitiumBlocklistSources: String
    let technitiumRateLimited: String

    // Healthchecks
    let healthchecksChecks: String
    let healthchecksSearch: String
    let healthchecksAll: String
    let healthchecksUp: String
    let healthchecksGrace: String
    let healthchecksDown: String
    let healthchecksPaused: String
    let healthchecksNew: String
    let healthchecksNoChecks: String
    let healthchecksLastPing: String
    let healthchecksNextPing: String
    let healthchecksSchedule: String
    let healthchecksTimeout: String
    let healthchecksGracePeriod: String
    let healthchecksTimezone: String
    let healthchecksMethods: String
    let healthchecksManualResume: String
    let healthchecksMethodsPostOnly: String
    let healthchecksMethodsAll: String
    let healthchecksIntegrations: String
    let healthchecksBadges: String
    let healthchecksCopyPingUrl: String
    let healthchecksChannels: String
    let healthchecksPings: String
    let healthchecksFlips: String
    let healthchecksLoadMorePings: String
    let healthchecksLoadMoreFlips: String
    let healthchecksEditCheck: String
    let healthchecksCreateCheck: String
    let healthchecksDeleteCheck: String
    let healthchecksDeleteConfirmTitle: String
    let healthchecksDeleteConfirmMessage: String
    let healthchecksPingBody: String
    let healthchecksBadgeAll: String
    let healthchecksBasics: String
    let healthchecksAdvanced: String
    let healthchecksFieldName: String
    let healthchecksFieldSlug: String
    let healthchecksFieldTags: String
    let healthchecksFieldDesc: String
    let healthchecksFieldType: String
    let healthchecksTypeSimple: String
    let healthchecksTypeCron: String
    let healthchecksFieldTimeout: String
    let healthchecksFieldSchedule: String
    let healthchecksFieldTimezone: String
    let healthchecksFieldGrace: String
    let healthchecksFieldChannels: String
    let healthchecksSlugHint: String
    let healthchecksTagsHint: String
    let healthchecksTimeoutHint: String
    let healthchecksScheduleHint: String
    let healthchecksTimezoneHint: String
    let healthchecksGraceHint: String
    let healthchecksChannelsHint: String
    let healthchecksNameRequired: String
    let healthchecksScheduleRequired: String
    let healthchecksTimeoutRequired: String
    let healthchecksReadOnly: String
    let healthchecksReadOnlyTitle: String
    let healthchecksReadOnlyMessage: String
    let healthchecksApiKeyBannerTitle: String
    let healthchecksApiKeyBannerBody: String

    // Pi-hole
    let piholeBlocking: String
    let piholeEnabled: String
    let piholeDisabled: String
    let piholeTotalQueries: String
    let piholeBlockedQueries: String
    let piholePercentBlocked: String
    let piholeTopBlocked: String
    let piholeTopDomains: String
    let piholeClients: String
    let piholeDomains: String
    let piholeGravity: String
    let piholeToggle: String
    let piholeQueries: String
    let piholeCached: String
    let piholeForwarded: String
    let piholeUniqueDomains: String
    let piholeBlockingWarningTitle: String
    let piholeBlockingWarningEnable: String
    let piholeBlockingWarningDisable: String
    let piholeBlockingDesc: String
    let piholeDisableDesc: String
    let piholeGravityUpdated: String
    let piholeOverview: String
    let piholeQueryActivity: String
    let piholeQueriesOverTime: String
    let piholeDomainManagement: String
    let piholeListType: String
    let piholeAllowed: String
    let piholeBlocked: String
    let piholeAddDomain: String
    let piholeDomainPlaceholder: String
    let piholeNoDomains: String
    let piholeAddDomainDesc: String

    let piholeDisablePermanently: String
    let piholeDisable1m: String
    let piholeDisable5m: String
    let piholeDisable1h: String
    let piholeDisableCustom: String
    let piholeCustomDisableTitle: String
    let piholeCustomDisableDesc: String
    let piholeCustomDisableMinutes: String
    let piholeQueryLog: String
    let piholeFilterSearch: String
    let piholeFilterAll: String
    let piholeFilterBlocked: String
    let piholeFilterAllowed: String
    let piholeFilterClient: String
    let piholeNoQueryResults: String

    // AdGuard Home
    let adguardProtection: String
    let adguardEnabled: String
    let adguardDisabled: String
    let adguardProtectionDesc: String
    let adguardDisableDesc: String
    let adguardDisablePermanently: String
    let adguardDisable1m: String
    let adguardDisable5m: String
    let adguardDisable1h: String
    let adguardDisableCustom: String
    let adguardCustomDisableTitle: String
    let adguardCustomDisableDesc: String
    let adguardCustomDisableMinutes: String
    let adguardOverview: String
    let adguardTotalQueries: String
    let adguardBlockedQueries: String
    let adguardPercentBlocked: String
    let adguardAvgProcessing: String
    let adguardTopQueried: String
    let adguardTopBlocked: String
    let adguardTopClients: String
    let adguardQueryActivity: String
    let adguardQuickActions: String
    let adguardSafety: String
    let adguardSafeBrowsing: String
    let adguardSafeSearch: String
    let adguardParental: String
    let adguardServerInfo: String
    let adguardVersion: String
    let adguardDnsAddress: String
    let adguardDnsPort: String
    let adguardHttpPort: String
    let adguardFilters: String
    let adguardBlocklists: String
    let adguardAllowlists: String
    let adguardFiltersEnabled: String
    let adguardRules: String
    let adguardQueryLog: String
    let adguardFilterSearch: String
    let adguardFilterAll: String
    let adguardFilterBlocked: String
    let adguardFilterAllowed: String
    let adguardFilterClient: String
    let adguardNoQueryResults: String
    let adguardAllow: String
    let adguardQueriesAxis: String
    let adguardUserRules: String
    let adguardAddRule: String
    let adguardAddRuleDesc: String
    let adguardRulePlaceholder: String
    let adguardNoRules: String
    let adguardBlockedServices: String
    let adguardNoBlockedServices: String
    let adguardBlockedServicesOther: String
    let adguardRewrites: String
    let adguardAddRewrite: String
    let adguardAddRewriteDesc: String
    let adguardRewriteDomain: String
    let adguardRewriteAnswer: String
    let adguardNoRewrites: String
    let adguardAddFilterList: String
    let adguardListType: String
    let adguardPresetLists: String
    let adguardCustomList: String
    let adguardAllowlistHint: String
    let adguardCustomListHint: String
    let adguardListName: String
    let adguardListUrl: String

    // Beszel
    let beszelSystems: String
    let beszelUp: String
    let beszelDown: String
    let beszelCpu: String
    let beszelMemory: String
    let beszelRam: String
    let beszelDisk: String
    let beszelNetwork: String
    let beszelUptime: String
    let beszelNoSystems: String
    let beszelSystemDetail: String
    let beszelOs: String
    let beszelKernel: String
    let beszelArch: String
    let beszelHostname: String
    let beszelCpuModel: String
    let beszelTotalMemory: String
    let beszelUsedMemory: String
    let beszelTotalDisk: String
    let beszelUsedDisk: String
    let beszelNetworkSent: String
    let beszelNetworkReceived: String
    let beszelRefreshRate: String
    let beszelCores: String
    let beszelSystemInfo: String
    let beszelResources: String
    let beszelNetworkTraffic: String
    let beszelContainers: String
    let beszelNoContainers: String
    let beszelCpuBreakdown: String
    let beszelCpuUser: String
    let beszelCpuSystem: String
    let beszelCpuNice: String
    let beszelCpuWait: String
    let beszelCpuIdle: String
    let beszelExtraMetrics: String
    let beszelGpu: String
    let beszelGpuUsage: String
    let beszelGpuPower: String
    let beszelGpuVram: String
    let beszelTemperature: String
    let beszelLoadAverage: String
    let beszelDiskIO: String
    let beszelBattery: String
    let beszelSwap: String
    let beszelSmartDevices: String
    let beszelHealthNone: String
    let beszelHealthStarting: String
    let beszelHealthHealthy: String
    let beszelHealthUnhealthy: String
    let beszelPerCoreCpu: String
    let beszelPerCoreSummary: String
    let beszelCpuCoreLabel: String
    let beszelDocker: String
    let beszelNetworkInterfaces: String
    let beszelExternalFilesystems: String
    let beszelRead: String
    let beszelWrite: String
    let beszelUpload: String
    let beszelDownload: String
    let beszelTotalUpload: String
    let beszelTotalDownload: String
    let beszelPassed: String
    let beszelFailing: String
    let beszelLevel: String
    let beszelRemaining: String
    let beszelTotal: String
    let beszelUsed: String
    let beszelModel: String
    let beszelCapacity: String
    let beszelType: String
    let beszelPowerOnHours: String
    let beszelPowerCycles: String
    let beszelSmartAttributes: String
    let beszelPodman: String
    let beszelMemoryUsage: String
    let beszelDockerCpuUsage: String
    let beszelDockerMemoryUsage: String
    let beszelDockerNetworkIO: String
    let beszelContainerInfo: String
    let beszelContainerLogs: String
    let beszelContainerDetails: String
    let beszelContainerFilter: String
    let beszelShowCharts: String
    let beszelHideCharts: String

    // Gitea
    let giteaRepos: String
    let giteaOrgs: String
    let giteaStars: String
    let giteaForks: String
    let giteaIssues: String
    let giteaPrivate: String
    let giteaPublic: String
    let giteaNoRepos: String
    let giteaLanguage: String
    let gitea2FAHint: String
    let gitea2FAHintMessage: String
    let giteaFiles: String
    let giteaFork: String
    let giteaDefault: String
    let giteaCommits: String
    let giteaBranches: String
    let giteaNoFiles: String
    let giteaNoBranches: String
    let giteaNoCommits: String
    let giteaNoIssues: String
    let giteaOpenIssues: String
    let giteaClosedIssues: String
    let giteaDefaultBranch: String
    let giteaSize: String
    let giteaLastUpdate: String
    let giteaReadme: String
    let giteaOk: String
    let giteaContributions: String
    let giteaFileContent: String
    let giteaLessActive: String
    let giteaMoreActive: String
    let giteaMyForks: String
    let giteaPreview: String
    let giteaCode: String
    let giteaSortRecent: String
    let giteaSortAlpha: String
    let giteaBranchLabel: String
    let giteaFileTooLarge: String

    // Nginx Proxy Manager
    let npmProxyHosts: String
    let npmRedirections: String
    let npmStreams: String
    let npm404Hosts: String
    let npmHostReport: String
    let npmNoProxyHosts: String
    let npmDisabled: String
    let npmOffline: String
    let npmCache: String
    let npmSecurity: String
    let loginHintNpm: String

    // PatchMon
    let patchmonHosts: String
    let patchmonSecurity: String
    let patchmonUpdates: String
    let patchmonNoHosts: String
    let patchmonStatusActive: String
    let patchmonStatusPending: String
    let patchmonReboot: String
    let patchmonLastUpdate: String
    let patchmonOverview: String
    let patchmonSystem: String
    let patchmonPackages: String
    let patchmonReports: String
    let patchmonRepositories: String
    let patchmonAgentQueue: String
    let patchmonNotes: String
    let patchmonIntegrations: String
    let patchmonHostGroups: String
    let patchmonAllGroups: String
    let patchmonOpenDetails: String
    let patchmonNoHostsInGroup: String
    let patchmonUpdatesOnly: String
    let patchmonShowAllPackages: String
    let patchmonNoPackages: String
    let patchmonNoUpdatesAvailable: String
    let patchmonNoReports: String
    let patchmonNoJobs: String
    let patchmonNoNotes: String
    let patchmonNoIntegrations: String
    let patchmonDocker: String
    let patchmonMachineId: String
    let patchmonAgentVersion: String
    let patchmonArchitecture: String
    let patchmonKernel: String
    let patchmonInstalledKernel: String
    let patchmonUptime: String
    let patchmonLoadAverage: String
    let patchmonGateway: String
    let patchmonDnsServers: String
    let patchmonInterfaces: String
    let patchmonQueueWaiting: String
    let patchmonQueueActive: String
    let patchmonQueueDelayed: String
    let patchmonQueueFailed: String
    let patchmonCores: String
    let patchmonSwap: String
    let patchmonExecutionTime: String
    let patchmonErrorBadRequest: String
    let patchmonErrorForbidden: String
    let patchmonErrorNotFound: String
    let patchmonErrorRateLimited: String
    let patchmonErrorServer: String
    let patchmonErrorInvalidCredentials: String
    let patchmonErrorIpNotAllowed: String
    let patchmonErrorAccessDenied: String
    let patchmonErrorHostNotFound: String
    let patchmonErrorInvalidHostId: String
    let patchmonErrorDeleteConstraint: String
    let patchmonErrorRetrying: String

    // Nginx Proxy Manager – CRUD
    let npmOverview: String
    let npmSslCertificates: String
    let npmAddProxyHost: String
    let npmEditProxyHost: String
    let npmAddRedirection: String
    let npmEditRedirection: String
    let npmAddStream: String
    let npmEditStream: String
    let npmAddDeadHost: String
    let npmEditDeadHost: String
    let npmAddCertificate: String
    let npmDomainNames: String
    let npmDomainNamesHint: String
    let npmForwardScheme: String
    let npmForwardHost: String
    let npmForwardPort: String
    let npmSslForced: String
    let npmCachingEnabled: String
    let npmWebsocket: String
    let npmHttp2: String
    let npmHsts: String
    let npmHstsSubdomains: String
    let npmAdvancedConfig: String
    let npmEnabled: String
    let npmForwardHttpCode: String
    let npmForwardDomain: String
    let npmPreservePath: String
    let npmIncomingPort: String
    let npmForwardingHost: String
    let npmForwardingPort: String
    let npmTcpForwarding: String
    let npmUdpForwarding: String
    let npmCertificate: String
    let npmCertificateNone: String
    let npmNiceName: String
    let npmLetsencryptEmail: String
    let npmDnsChallenge: String
    let npmLetsencryptAgree: String
    let npmRenew: String
    let npmDelete: String
    let npmDeleteConfirm: String
    let npmDeleteConfirmTitle: String
    let npmNoRedirections: String
    let npmNoStreams: String
    let npmNoDeadHosts: String
    let npmNoCertificates: String
    let npmExpires: String
    let npmExpired: String
    let npmLetsencrypt: String
    let npmCustomCert: String
    let npmProvider: String
    let npmAccessList: String
    let npmAccessListNone: String
    let npmAddAccessList: String
    let npmEditAccessList: String
    let npmUsers: String
    let npmAuditLogs: String
    let npmSettings: String
    let npmComingSoon: String
    let npmNoUsers: String
    let npmNoAuditLogs: String
    let npmNoSettings: String
    let npmAddUser: String
    let npmEditUser: String
    let npmUserEmail: String
    let npmUserName: String
    let npmUserNickname: String
    let npmUserPassword: String
    let npmUserPasswordHint: String
    let npmUserRole: String
    let npmUserRoleAdmin: String
    let npmUserRoleUser: String
    let npmAuditActionCreated: String
    let npmAuditActionUpdated: String
    let npmAuditActionDeleted: String
    let npmAccessListUsers: String
    let npmAccessListClients: String
    let npmAccessListUsername: String
    let npmAccessListPassword: String
    let npmAccessListAddress: String
    let npmAccessListAllow: String
    let npmAccessListDeny: String
    let npmAccessListNoUsers: String
    let npmAccessListNoClients: String
    let npmAccessListRules: String
    let npmSaveSuccess: String
    let npmDeleteSuccess: String
    let npmRenewSuccess: String
    let loginHintNpm2FAWarning: String

    // Units
    let unitDays: String
    let unitHours: String
    let unitMinutes: String
    let unitGB: String
    let unitMB: String
    let unitKB: String
    
    let timeToday: String
    let timeNow: String
    let timeHoursAgo: String
    let timeDayAgo: String
    let timeDaysAgo: String
    let timeMonthsAgo: String

    // Settings
    let settingsPreferences: String
    let settingsLanguage: String
    let settingsTheme: String
    let settingsThemeLight: String
    let settingsThemeDark: String
    let settingsItalian: String
    let settingsEnglish: String
    let settingsFrench: String
    let settingsSpanish: String
    let settingsGerman: String
    let settingsChinese: String
    let settingsServices: String
    let settingsConfiguredServices: String
    let settingsDisconnect: String
    let settingsDisconnectConfirm: String
    let settingsDisconnectMessage: String
    let settingsVersion: String
    let settingsCheckForUpdates: String
    let settingsCheckForUpdatesDesc: String
    let settingsCheckForUpdatesNow: String
    let settingsUpdateBannerTitle: String
    let settingsUpdateBannerBody: String
    let settingsUpdateAction: String
    let settingsUpdateDismiss: String
    let updatePopupTitle: String
    let updatePopupBody: String
    let settingsConnected: String
    let settingsNotConnected: String
    let settingsFallbackUrl: String
    let settingsCopied: String
    let settingsThemeAuto: String
    let settingsAppIcon: String
    let settingsAppIconDefault: String
    let settingsAppIconDark: String
    let settingsAppIconClearLight: String
    let settingsAppIconClearDark: String
    let settingsAppIconTintedLight: String
    let settingsAppIconTintedDark: String
    let settingsHomeCyberpunkCards: String
    let settingsHomeCyberpunkCardsDesc: String
    let settingsAbout: String
    let settingsAboutSource: String
    let settingsServicesGroup: String
    let settingsConfiguredServicesDesc: String
    let settingsAppearance: String
    let settingsExpand: String
    let settingsCollapse: String
    let settingsHideService: String
    let settingsShowService: String
    let settingsHideServiceGeneric: String
    let settingsShowServiceGeneric: String
    let settingsHiddenBadge: String
    let settingsNoInstances: String
    let settingsInstanceSingular: String
    let settingsInstancePlural: String
    let settingsAddInstance: String
    let settingsSetDefault: String
    let settingsDeleteInstanceTitle: String
    let settingsDeleteInstanceMessage: String
    let settingsFallbackPrefix: String
    let settingsMoveUp: String
    let settingsMoveDown: String
    let settingsDebug: String
    let settingsDebugLogs: String
    let debugLogsCopied: String
    let debugLogsErrorTitle: String
    let debugLogsOpenSettings: String
    let debugLogsSearchPlaceholder: String
    let debugLogsAuthMessage: String
    let debugLogsFilterSource: String
    let debugLogsNoResults: String
    let actionEdit: String

    // Security
    let securityTitle: String
    let securitySetupPin: String
    let securitySetupPinDesc: String
    let securityConfirmPin: String
    let securityConfirmPinDesc: String
    let securityEnterPin: String
    let securityEnterPinDesc: String
    let securityWrongPin: String
    let securityEnableBiometric: String
    let securityBiometricDesc: String
    let securityFaceId: String
    let securityTouchId: String
    let securityChangePin: String
    let securityDisable: String
    let securityDisableConfirm: String
    let securityDisableMessage: String
    let securityPinMismatch: String
    let securityBiometricReason: String
    let securityNewPin: String
    let securityNewPinDesc: String
    let securityCurrentPin: String
    let securityCurrentPinDesc: String
    let securityNotConfigured: String
    let securitySkip: String

    // Multi-instance
    let badgeDefault: String
    let dashboardInstances: String
    let craftyServers: String
    let craftyRunningServers: String
    let craftyTotalPlayers: String
    let craftyNoServers: String
    let craftyPlayers: String
    let craftyWorld: String
    let craftyVersion: String
    let craftyMemory: String
    let craftyCPU: String
    let craftyType: String
    let craftyStatusRunning: String
    let craftyStatusStopped: String
    let craftyStatusStarting: String
    let craftyStatusUpdating: String
    let craftyStatusCrashed: String
    let craftyStatusOffline: String
    let craftyUpdateExecutable: String
    let craftyCommandPlaceholder: String
    let craftyCommandHint: String
    let wakapiCodedToday: String
    let wakapiTotalTimeCoded: String
    let wakapiSectionLanguages: String
    let wakapiSectionProjects: String
    let wakapiSectionEditors: String
    let wakapiSectionMachines: String
    let wakapiSectionOperatingSystems: String
    let wakapiSectionLabels: String
    let wakapiSectionCategories: String
    let wakapiSectionBranches: String
    let wakapiActiveFilter: String
    let wakapiClearFilter: String
    let wakapiIntervalToday: String
    let wakapiIntervalYesterday: String
    let wakapiIntervalLast7Days: String
    let wakapiIntervalLast30Days: String
    let wakapiIntervalLast6Months: String
    let wakapiIntervalLastYear: String
    let wakapiIntervalAllTime: String
    let wakapiIntervalLabel: String
    let wakapiRecentActivity: String
    let wakapiActivityHeatmapTitle: String
    let wakapiLast30DaysWindow: String
    let wakapiLast20WeeksWindow: String
    let wakapiAveragePerDay: String
    let wakapiBestDay: String
    let wakapiNoRecentActivity: String
    let jellystatWatchTimeHome: String
    let jellystatOverviewSubtitle: String
    let jellystatWatchTime: String
    let jellystatViews: String
    let jellystatWindowDaysFormat: String
    let jellystatActiveDays: String
    let jellystatDaysWithPlayback: String
    let jellystatTopLibrary: String
    let jellystatNoActivity: String
    let jellystatAvgPerDay: String
    let jellystatAverageWatchTime: String
    let jellystatMediaTypeBreakdown: String
    let jellystatSongs: String
    let jellystatMovies: String
    let jellystatEpisodes: String
    let jellystatOther: String
    let jellystatRecentTrend: String
    let jellystatNoDataForPeriod: String
    let jellystatNoData: String
    let jellystatViewsSuffix: String

    // Plex
    let plexOverviewSubtitle: String
    let plexLibraries: String
    let plexTotalItems: String
    let plexActiveSessions: String
    let plexRecentlyAdded: String
    let plexWatchHistory: String
    let plexNoRecentItems: String
    let plexNoData: String
    let plexMovies: String
    let plexShows: String
    let plexEpisodes: String
    let plexMusic: String

    let loginEditTitle: String
    let loginEditSubtitle: String
    let loginLabel: String
    let loginFallbackOptional: String
    let loginPasswordIfChanging: String
    let loginErrorPasswordRequired: String
    let loginShowPassword: String
    let loginHidePassword: String
    let tailscaleBadge: String

    // Bookmarks
    let bookmarkTitle: String
    let bookmarkDesc: String
    let bookmarkUrl: String
    let bookmarkCategory: String
    let bookmarkCategoryNew: String
    let bookmarkIcon: String
    let bookmarkAdd: String
    let bookmarkEdit: String
    let categoryName: String
    let categoryAdd: String
    let categoryEdit: String
    let categoryDelete: String
    let categoryDeleteConfirm: String
    let categoryEmpty: String
    let categoryUncategorized: String
    let categorySymbolPlaceholder: String
    let categorySymbolExample: String
    let bookmarkUseFavicon: String
    let bookmarkSfSymbolPrompt: String

    // Tailscale v2
    let tailscaleOpen: String
    let tailscaleOpenDesc: String
    let tailscaleSecure: String
    let tailscaleConnected: String
    let tailscaleNotConnected: String

    // Bookmarks v2
    let categoryColor: String
    let bookmarkFavicon: String
    let bookmarkSymbol: String
    let bookmarkSelfhst: String
    let bookmarkAutoFavicon: String
    let bookmarkEnterUrl: String
    let bookmarkTags: String
    let bookmarkSearchPrompt: String
    let bookmarkToggleView: String
    let bookmarkEnterSelfhst: String
    let bookmarkPreviewSelfhst: String
    let bookmarkImagePreview: String
    let bookmarkSelfhstHint: String
    let bookmarkReorder: String
    let bookmarkReorderCategoryLabel: String
    let bookmarkReorderBookmarkLabel: String
    let bookmarkExpandCategory: String
    let bookmarkCollapseCategory: String
    let bookmarkMoveToCategory: String
    let categoryActions: String

    // Onboarding v2
    let onboardingWelcome: String
    let onboardingWelcomeDesc: String
    let onboardingWelcomeButton: String
    let onboardingAskPin: String
    let onboardingAskPinYes: String
    let onboardingAskPinNo: String

    // Errors
    let errorNotConfigured: String
    let errorInvalidURL: String
    let errorNetwork: String
    let errorHttp: String
    let errorDecoding: String
    let errorUnauthorized: String
    let errorBothFailed: String
    let errorUnknown: String
    let errorAtsRequiresSecure: String
    let loginErrorQbittorrentAuth: String
    let loginErrorQbittorrentCookie: String
    let unknown: String
    let none: String
    let statusOn: String
    let statusOff: String

    // Backup & Restore
    let backupTitle: String
    let backupInfoTitle: String
    let backupInfoDesc: String
    let backupExportTitle: String
    let backupExportAction: String
    let backupExportDesc: String
    let backupExportSuccess: String
    let backupImportTitle: String
    let backupImportAction: String
    let backupImportDesc: String
    let backupImportDecrypt: String
    let backupImportPasswordDesc: String
    let backupImportFileError: String
    let backupImportApply: String
    let backupImportSuccess: String
    let backupImportPreviewTitle: String
    let backupPreviewServices: String
    let backupPreviewUnknown: String
    let backupPreviewWarning: String
    let backupPasswordPlaceholder: String
    let backupPasswordConfirm: String
    let backupPasswordDesc: String
    let backupPasswordRequired: String
    let backupPasswordTooShort: String
    let backupPasswordMismatch: String
    let backupSelectionTitle: String
    let backupSelectionSubtitle: String
    let backupSelectionAll: String
    let backupSelectionHome: String
    let backupSelectionArr: String
    let backupSelectionEmpty: String
    let backupSelectionRequired: String
    let backupSelectionSelectedCount: String
    let backupRememberSelectionTitle: String
    let backupRememberSelectionSubtitle: String

    // Proxmox
    let serviceProxmox: String
    let serviceProxmoxDesc: String
    let loginHintProxmox: String
    let serviceTruenasDesc: String
    let loginHintTruenas: String
    let truenasDashboard: String
    let truenasSystem: String
    let truenasVersion: String
    let truenasUptime: String
    let truenasHost: String
    let truenasProduct: String
    let truenasPools: String
    let truenasHealthyPools: String
    let truenasStorageUsed: String
    let truenasDisks: String
    let truenasShares: String
    let truenasServices: String
    let truenasRunningServices: String
    let truenasWorkloads: String
    let truenasApps: String
    let truenasVirtualMachines: String
    let truenasSMB: String
    let truenasNFS: String
    let truenasISCSI: String
    let truenasRunning: String
    let truenasEnabled: String
    let truenasStopped: String
    let truenasAlerts: String
    let truenasNoAlerts: String
    let truenasAvailable: String
    let truenasUsed: String
    let truenasPoolStatus: String
    let truenasReadOnlyApiKey: String
    let truenasSecureTransportRequired: String
    let loginAllowSelfSigned: String
    let loginRequireValidTLS: String
    let loginTLSDesc: String
    let proxmoxCredentialsHint: String
    let proxmoxApiTokenRecommendedHint: String
    let proxmoxConsoleCredentialsOnly: String
    let proxmoxOtpRecoveryHint: String
    let proxmoxApiTokenStructuredMode: String
    let proxmoxApiTokenPasteMode: String
    let proxmoxApiUser: String
    let proxmoxApiTokenId: String
    let proxmoxApiTokenSecret: String
    let proxmoxCustomRealmHint: String
    let proxmoxInvalidApiToken: String
    let proxmoxDashboard: String
    let proxmoxCreateGuest: String
    let proxmoxProvisioning: String
    let proxmoxNodes: String
    let proxmoxNode: String
    let proxmoxVMs: String
    let proxmoxContainers: String
    let proxmoxStorage: String
    let proxmoxTasks: String
    let proxmoxOverview: String
    let proxmoxRunning: String
    let proxmoxStopped: String
    let proxmoxNodeOnline: String
    let proxmoxNodeOffline: String
    let proxmoxUptime: String
    let proxmoxKernel: String
    let proxmoxSystemInfo: String
    let proxmoxResources: String
    let proxmoxCpuLabel: String
    let proxmoxRamLabel: String
    let proxmoxIsoImages: String
    let proxmoxOsLabel: String
    let proxmoxBiosLabel: String
    let proxmoxScsiLabel: String
    let proxmoxIpv6Label: String
    let proxmoxIpv6GatewayLabel: String
    let proxmoxDnsLabel: String
    let proxmoxCidrLabel: String
    let proxmoxNetmaskLabel: String
    let proxmoxClusterLabel: String
    let proxmoxDirectionLabel: String
    let proxmoxProtocolLabel: String
    let proxmoxNoneLabel: String
    let proxmoxSizeLabel: String
    let proxmoxFullLabel: String
    let proxmoxNearFullLabel: String
    let proxmoxMonitoringLabel: String
    let proxmoxOsdLabel: String
    let proxmoxPgLabel: String
    let proxmoxMonsLabel: String
    let proxmoxCrushWeight: String
    let proxmoxReweight: String
    let proxmoxTcpUdpIcmp: String
    let proxmoxDestPortPlaceholder: String
    let proxmoxInLabel: String
    let proxmoxOutLabel: String
    let proxmoxZstdLabel: String
    let proxmoxLzoLabel: String
    let proxmoxGzipLabel: String
    let proxmoxVmidLabel: String
    let proxmoxHaLabel: String
    let proxmoxPveLabel: String
    let proxmoxSwapLabel: String
    let proxmoxActions: String
    let proxmoxConfiguration: String
    let proxmoxSnapshots: String
    let proxmoxCreateSnapshot: String
    let proxmoxNoSnapshots: String
    let proxmoxSnapshotName: String
    let proxmoxSnapshotDescription: String
    let proxmoxIncludeRAM: String
    let proxmoxConsole: String
    let proxmoxOpenConsole: String
    let proxmoxConsoleLoading: String
    let proxmoxRetry: String
    let proxmoxConsoleCookieError: String
    let proxmoxConsoleAuthError: String
    let proxmoxConsoleCertError: String
    let proxmoxConsoleGenericError: String
    let proxmoxConfirmAction: String
    let proxmoxConfirmMessage: String
    let proxmoxAuthMode: String
    let proxmoxCredentialsMode: String
    let proxmoxApiTokenMode: String
    let proxmoxApiTokenPlaceholder: String
    let proxmoxApiTokenHint: String
    let proxmoxRealm: String
    let proxmoxGuestsRunning: String
    let proxmoxGuestOverview: String
    let proxmoxGuestName: String
    let proxmoxHostname: String
    let proxmoxAgentVersion: String
    let proxmoxDisks: String
    let proxmoxDisk: String
    let proxmoxDescription: String
    let proxmoxTags: String
    let proxmoxCpuType: String
    let proxmoxCpuCores: String
    let proxmoxSockets: String
    let proxmoxDiskSize: String
    let proxmoxRootDisk: String
    let proxmoxSwap: String
    let proxmoxAgent: String
    let proxmoxGuestUsers: String
    let proxmoxNoGuestUsers: String
    let proxmoxGuestFilesystems: String
    let proxmoxNoGuestFilesystems: String
    let proxmoxGuestTimezone: String
    let proxmoxGuestCommands: String
    let proxmoxNoGuestCommands: String
    let proxmoxLoginTime: String
    let proxmoxType: String
    let proxmoxBallooning: String
    let proxmoxStartupPolicy: String
    let proxmoxBootOrder: String
    let proxmoxMachine: String
    let proxmoxBootOnStart: String
    let proxmoxProtection: String
    let proxmoxPaused: String
    let proxmoxUnknown: String
    let proxmoxOk: String
    let proxmoxServices: String
    let proxmoxNetwork: String
    let proxmoxSelectNode: String
    let proxmoxAddressing: String
    let proxmoxDhcp: String
    let proxmoxStaticAddress: String
    let proxmoxManual: String
    let proxmoxIPv4Address: String
    let proxmoxCeph: String
    let proxmoxPools: String
    let proxmoxPoolMembers: String
    let proxmoxCpu: String
    let proxmoxOs: String
    let proxmoxBios: String
    let proxmoxScsi: String
    let proxmoxIpv6: String
    let proxmoxDns: String
    let proxmoxCidr: String
    let proxmoxNetmask: String
    let proxmoxCluster: String
    let proxmoxNone: String
    let proxmoxSize: String
    let proxmoxFull: String
    let proxmoxNearFull: String
    let proxmoxMonitoring: String
    let proxmoxMon: String
    let proxmoxOsd: String
    let proxmoxLoadAverage: String
    let proxmoxPlacementGroup: String
    let proxmoxDeletePool: String
    let proxmoxDeletePoolMessage: String
    let proxmoxNoPoolMembers: String
    let proxmoxEditComment: String
    let proxmoxNoComment: String
    let proxmoxSearchPrompt: String
    let proxmoxNoSearchResults: String
    let proxmoxGuests: String
    let proxmoxFirewall: String
    let proxmoxFirewallRules: String
    let proxmoxFirewallStatus: String
    let proxmoxFirewallToggle: String
    let proxmoxFirewallEnableConfirm: String
    let proxmoxFirewallDisableConfirm: String
    let proxmoxRules: String
    let proxmoxAddRule: String
    let proxmoxNoRules: String
    let proxmoxDirection: String
    let proxmoxIn: String
    let proxmoxOut: String
    let proxmoxProtocol: String
    let proxmoxDestinationPort: String
    let proxmoxAddresses: String
    let proxmoxOptions: String
    let proxmoxComment: String
    let proxmoxSource: String
    let proxmoxDestination: String
    let proxmoxEnabled: String
    let proxmoxDisabled: String
    let proxmoxActive: String
    let proxmoxTotal: String
    let proxmoxInactive: String
    let proxmoxAutostart: String
    let proxmoxSearchDomain: String
    let proxmoxInterfaces: String
    let proxmoxNoNetworkInterfaces: String
    let proxmoxAddress: String
    let proxmoxGateway: String
    let proxmoxBridge: String
    let proxmoxVlanTag: String
    let proxmoxMacAddress: String
    let proxmoxRateLimit: String
    let proxmoxMountPoint: String
    let proxmoxBridgePorts: String
    let proxmoxBondSlaves: String
    let proxmoxBondMode: String
    let proxmoxAvailableUpdates: String
    let proxmoxUnknownPackage: String
    let proxmoxSystemServices: String
    let proxmoxNoServices: String
    let proxmoxReload: String
    let proxmoxNoContent: String
    let proxmoxItems: String
    let proxmoxDeleteVolume: String
    let proxmoxDeleteVolumeMessage: String
    let proxmoxClusterHealth: String
    let proxmoxClusterInfo: String
    let proxmoxStorageUsage: String
    let proxmoxAllItems: String
    let proxmoxImages: String
    let proxmoxBackups: String
    let proxmoxSnippets: String
    let proxmoxPerformance: String
    let proxmoxUtilization: String
    let proxmoxTraffic: String
    let proxmoxDiskActivity: String
    let proxmoxNoMetricsAvailable: String
    let proxmoxLastHour: String
    let proxmoxLastDay: String
    let proxmoxLastWeek: String
    let proxmoxAvailable: String
    let proxmoxRead: String
    let proxmoxWrite: String
    let proxmoxReadIops: String
    let proxmoxWriteIops: String
    let proxmoxCrushRule: String
    let proxmoxHealth: String
    let proxmoxRawConfiguration: String
    let proxmoxNoDevices: String
    let proxmoxTemplate: String
    let proxmoxTemplates: String
    let proxmoxLocked: String
    let proxmoxTemplateGuestHint: String
    let proxmoxLockedGuestHint: String
    let proxmoxBackupJobs: String
    let proxmoxScheduledJobs: String
    let proxmoxNoBackupJobs: String
    let proxmoxTotalJobs: String
    let proxmoxHaReplication: String
    let proxmoxHaResources: String
    let proxmoxHaGroups: String
    let proxmoxReplicationJobs: String
    let proxmoxRestricted: String
    let proxmoxNoFailback: String
    let proxmoxLogOutput: String
    let proxmoxShowAllLogs: String
    let proxmoxNoLogData: String
    let proxmoxFailedLoadLog: String
    let proxmoxUser: String
    let proxmoxStartTime: String
    let proxmoxDuration: String
    let proxmoxExitStatus: String
    let proxmoxStartBackup: String
    let proxmoxCreateClone: String
    let proxmoxStartMigration: String
    let proxmoxSnapshotMode: String
    let proxmoxCurrentSnapshot: String
    let proxmoxRestore: String
    let proxmoxRestoreBackup: String
    let proxmoxRestoreAsUnique: String
    let proxmoxForceOverwrite: String
    let proxmoxRestoreGuestType: String
    let proxmoxRestoreSourceVmid: String
    let proxmoxBackupArchive: String
    let proxmoxMode: String
    let proxmoxCompression: String
    let proxmoxPassword: String
    let proxmoxPasswordOptional: String
    let proxmoxTargetNode: String
    let proxmoxSourceNode: String
    let proxmoxRam: String
    let proxmoxTimeframe: String
    let proxmoxHotplug: String
    let proxmoxNuma: String
    let proxmoxDiscard: String
    let proxmoxSsd: String
    let proxmoxIpv6Gateway: String
    let proxmoxGuestTypeQemu: String
    let proxmoxGuestTypeLxc: String
    let proxmoxOnlineMigration: String
    let proxmoxFullClone: String
    let proxmoxNewVmid: String
    let proxmoxOptionalName: String
    let proxmoxNoBackupStorage: String
    let proxmoxNoTargetNodes: String
    let proxmoxRestart: String
    let proxmoxShutdown: String
    let proxmoxSuspend: String
    let proxmoxResume: String
    let proxmoxClone: String
    let proxmoxMigrate: String
    let proxmoxCurrentOperation: String
    let proxmoxTaskIdentifier: String
    let proxmoxLastUpdate: String
    let proxmoxOpenTaskLog: String
    let proxmoxRollbackSnapshot: String
    let proxmoxDeleteSnapshot: String
    let proxmoxTaskLog: String
    let proxmoxClientNotConfigured: String
    let proxmoxNotify: String
    let proxmoxScope: String
    let proxmoxAllGuests: String
    let proxmoxPool: String
    let proxmoxCompress: String
    let proxmoxNoneValue: String
    let proxmoxOtherValue: String
    let proxmoxInstallSource: String
    let proxmoxBlankDisk: String
    let proxmoxIsoImage: String
    let proxmoxContainerTemplate: String
    let proxmoxSourceTemplate: String
    let proxmoxNoTemplatesAvailable: String
    let proxmoxUseSourceDefault: String
    let proxmoxRefreshVmid: String
    let proxmoxSuggestedVmid: String
    let proxmoxCompleteRequiredFields: String
    let proxmoxCreateVM: String
    let proxmoxCreateContainer: String
    let proxmoxCreateTemplate: String
    let proxmoxDeployTemplate: String
    let proxmoxDeployFromTemplate: String
    let proxmoxOpenCreatedGuest: String
    let proxmoxNewVMDescription: String
    let proxmoxNewContainerDescription: String
    let proxmoxTemplateCloneDescription: String
    let proxmoxProvisionNoIso: String
    let proxmoxProvisionNoContainerTemplates: String
    let proxmoxProvisionNoBridges: String
    let proxmoxUnprivileged: String
    let proxmoxConvertToTemplate: String
    let proxmoxConvertToTemplateAfterCreate: String
    let proxmoxClusterResources: String
    let proxmoxClusterSummary: String
    let proxmoxTotalNodes: String
    let proxmoxRunningVMs: String
    let proxmoxRunningLXCs: String
    let proxmoxStorageUsed: String
    let proxmoxFilterAll: String
    let proxmoxFilterNodes: String
    let proxmoxFilterVMs: String
    let proxmoxFilterLXCs: String
    let proxmoxFilterStorage: String
    let proxmoxFilterRunning: String
    let proxmoxFilterStopped: String
    let proxmoxNoResources: String
    let proxmoxNoResourcesDescription: String
    let proxmoxResourceType: String
    let proxmoxPoolMemberDetail: String
    let proxmoxEditConfig: String
    let proxmoxConfigEditName: String
    let proxmoxConfigEditDesc: String
    let proxmoxConfigEditCores: String
    let proxmoxConfigEditSockets: String
    let proxmoxConfigEditMemory: String
    let proxmoxConfigEditBalloon: String
    let proxmoxConfigEditOnBoot: String
    let proxmoxConfigEditProtection: String
    let proxmoxConfigSaved: String
    let proxmoxConfigSaveError: String

    let debugLogsEmpty: String
    let securityLockoutMessage: String

    // Pterodactyl
    let servicePterodactylDesc: String
    let loginHintPterodactyl: String
    let pterodactylNoServers: String
    let pterodactylRunningServers: String
    let pterodactylTotalServers: String
    let pterodactylCPU: String
    let pterodactylRAM: String
    let pterodactylDisk: String
    let pterodactylUptime: String
    let pterodactylStatusRunning: String
    let pterodactylStatusStopping: String
    let pterodactylStatusStarting: String
    let pterodactylStatusOffline: String
    let pterodactylStatusSuspended: String
    let pterodactylStatusInstalling: String

    // Calagopus
    let serviceCalagopusDesc: String
    let loginHintCalagopus: String
    let serviceOpenListDesc: String
    let loginHintOpenList: String
    let loginOpenListTokenOptional: String
    let filesCopyLink: String
    let filesOpenInSenPlayer: String
    let filesSearchPlaceholder: String
    let filesEmptyFolder: String
    let filesRootTitle: String
    let filesOpen: String
    let filesPlay: String
    let filesPlayWith: String
    let filesPlayFooter: String
    let filesDetails: String
    let filesPreview: String
    let filesOpenExternal: String
    let filesPreviewFailed: String
    let filesNoInlinePreview: String
    let filesShowSource: String
    let filesShowPreview: String
    let filesPreviewType: String
    let filesKindVideo: String
    let filesKindAudio: String
    let filesKindImage: String
    let filesKindMarkdown: String
    let filesKindHTML: String
    let filesKindText: String
    let filesKindPDF: String
    let filesKindFile: String
    let filesSelect: String
    let filesDeselect: String
    let filesSelectedCount: String
    let filesLinkCopied: String
    let filesDeleted: String
    let filesDeleteConfirm: String
    let filesNoPlayableURL: String
    let filesPlayerOpenFailed: String
    let filesOpenedInPlayer: String
    let filesNameLabel: String
    let filesPathLabel: String
    let filesSizeLabel: String
    let filesModifiedLabel: String
    let filesNewFolder: String
    let filesFolderName: String
    let filesFolderCreated: String
    let filesUpload: String
    let filesUploadedCount: String
    let filesProviderLabel: String
    let filesCloudDirectLinkWarning: String
    let filesNewTextFile: String
    let filesFileName: String
    let filesRename: String
    let filesDownload: String
    let filesCopy: String
    let filesMove: String
    let filesExtract: String
    let filesMoveTo: String
    let filesCopyTo: String
    let filesExtractTo: String
    let filesFileCreated: String
    let filesRenamed: String
    let filesMoved: String
    let filesCopied: String
    let filesExtractStarted: String
    let filesDownloadedCount: String
    let filesEdit: String
    let filesSave: String
    let filesBuiltInPlayer: String
    let filesBuiltInPlayerHint: String
    let filesPlaySectionBuiltIn: String
    let filesPlaySectionExternal: String
    let filesPlayerMayNeedInstall: String
    let filesTasks: String
    let filesTaskTypeLabel: String
    let filesTaskPhaseLabel: String
    let filesTasksUndone: String
    let filesTasksDone: String
    let filesTaskEmpty: String
    let filesTaskCancel: String
    let filesTaskRetry: String
    let filesTaskDelete: String
    let filesTaskClearDone: String
    let filesTaskClearSucceeded: String
    let filesTaskRetryFailed: String
    let filesTaskRefresh: String
    let filesTaskRetrySelected: String
    let filesTaskDeleteSelected: String
    let filesTaskCancelSelected: String
    let filesTaskExpand: String
    let filesTaskCollapse: String
    let filesTaskExpandAll: String
    let filesTaskCollapseAll: String
    let filesTaskCreator: String
    let filesTaskSelectAll: String
    let filesTaskDeselectAll: String
    let filesTaskMineOnly: String
    let filesTaskTypeCopy: String
    let filesTaskTypeMove: String
    let filesTaskTypeUpload: String
    let filesTaskTypeOfflineDownload: String
    let filesTaskTypeOfflineTransfer: String
    let filesTaskTypeDecompress: String
    let filesTaskTypeDecompressUpload: String
    let filesTaskStatePending: String
    let filesTaskStateRunning: String
    let filesTaskStateSucceeded: String
    let filesTaskStateCanceling: String
    let filesTaskStateCanceled: String
    let filesTaskStateErrored: String
    let filesTaskStateFailing: String
    let filesTaskStateFailed: String
    let filesTaskStateWaitingRetry: String
    let filesTaskStateBeforeRetry: String
    let calagopusNoServers: String
    let calagopusRunningServers: String
    let calagopusTotalServers: String
    let calagopusCPU: String
    let calagopusRAM: String
    let calagopusDisk: String
    let calagopusUptime: String
    let calagopusStatusRunning: String
    let calagopusStatusStopping: String
    let calagopusStatusStarting: String
    let calagopusStatusOffline: String
    let calagopusStatusSuspended: String
}

// MARK: - Factory

extension Translations {
    static func forLanguage(_ language: Language) -> Translations {
        switch language {
        case .en: return .english
        case .zh: return .chinese
        }
    }

    static func current() -> Translations {
        let systemCode = Locale.preferredLanguages.first
        let systemLang = Language.resolve(code: systemCode)
        let savedLang = UserDefaults.standard.string(forKey: "homelab_language")
        let language = Language.resolve(code: savedLang ?? systemLang.rawValue)
        return forLanguage(language)
    }
}

// MARK: - Localizer (accessed via environment)

@dynamicMemberLookup
@MainActor
@Observable
final class TranslationCatalog {
    private var translations: Translations

    init(_ translations: Translations) {
        self.translations = translations
    }

    subscript<T>(dynamicMember keyPath: KeyPath<Translations, T>) -> T {
        translations[keyPath: keyPath]
    }

    var snapshot: Translations {
        translations
    }

    func update(_ translations: Translations) {
        self.translations = translations
    }
}

@Observable
@MainActor
final class Localizer {
    static let shared = Localizer()
    private let catalog: TranslationCatalog
    var language: Language {
        didSet {
            guard language != oldValue else { return }
            catalog.update(Translations.forLanguage(language))
        }
    }

    init(language: Language? = nil) {
        let resolvedLanguage = language ?? {
            let systemLang = Language.resolve(code: Locale.preferredLanguages.first)
            let savedLang = UserDefaults.standard.string(forKey: "homelab_language")
            return Language.resolve(code: savedLang ?? systemLang.rawValue)
        }()

        self.language = resolvedLanguage
        self.catalog = TranslationCatalog(Translations.forLanguage(resolvedLanguage))
    }

    var t: TranslationCatalog { catalog }
    var translations: Translations { catalog.snapshot }

    func greetingKey() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return t.greetingMorning
        case 12..<18: return t.greetingAfternoon
        default:      return t.greetingEvening
        }
    }
}
struct ArrStrings {
    let arrGroupTitle: String

    let tutorialTitle: String
    let tutorialBody: String
    let tutorialStepConnect: String
    let tutorialStepOpen: String
    let tutorialStepAutomations: String
    let tutorialActionConfigure: String
    let tutorialActionDismiss: String
    let quickSetupTitle: String
    let quickSetupSubtitle: String
    let addService: (String) -> String

    let connection: String
    let download: String
    let upload: String
    let torrents: String
    let searchTorrents: String

    let filterAll: String
    let filterActive: String
    let filterDone: String
    let filterPaused: String

    let recheck: String
    let reannounce: String
    let deleteWithData: String

    let altLimitsToggled: String
    let allResumed: String
    let allPaused: String
    let torrentResumed: String
    let torrentPaused: String
    let torrentDeleted: String
    let torrentAndDataDeleted: String
    let recheckStarted: String
    let reannounceQueued: String

    let radarrVersion: String
    let sonarrVersion: String
    let lidarrVersion: String
    let branch: String

    let searchMissing: String
    let refreshIndex: String
    let rssSync: String
    let rescan: String
    let downloadedScan: String
    let healthCheck: String
    let contentSearchTitle: String
    let contentSearchPlaceholder: (String) -> String
    let searchNow: String
    let clearSearch: String
    let searchNoResults: String
    let searchStatusInLibrary: String
    let searchStatusMonitored: String
    let searchStatusUnmonitored: String
    let searchStatusEnded: String
    let searchStatusPending: String
    let searchStatusApproved: String
    let searchStatusAvailable: String
    let searchStatusProcessing: String
    let openDetails: String
    let requestContent: String
    let requestQueued: String
    let requestConfigurationTitle: (String) -> String
    let requestConfigurationMessage: String
    let requestQualityProfile: String
    let requestRootFolder: String
    let requestLanguageProfile: String
    let requestMetadataProfile: String

    let downloadingWithCount: (Int) -> String
    let latestAdditions: String
    let tvSeriesLibrary: String
    let latestAlbums: String
    let recentHistory: String
    let health: String
    let upcoming: String
    let noUpcoming: String

    let movieSearchQueued: String
    let movieRefreshQueued: String
    let seriesSearchQueued: String
    let seriesRefreshQueued: String
    let albumSearchQueued: String
    let artistRefreshQueued: String
    let rssSyncQueued: String
    let rescanQueued: String
    let downloadedScanQueued: String
    let healthCheckQueued: String

    let requests: String
    let approveOldestPending: String
    let declineOldestPending: String
    let recentMediaScan: String
    let fullMediaScan: String
    let indexers: String
    let apps: String
    let issues: String
    let testIndexers: String
    let syncApps: String
    let indexerTestStarted: String
    let applicationSyncStarted: String

    let subtitles: String
    let vpn: String
    let restartVpnTunnel: String
    let provider: String
    let forwardedPort: String
    let service: String
    let newSession: String
    let sessionIds: String
    let statusLabel: String
    let versionLabel: String
    let messageLabel: String
    let urlLabel: String
    let fallbackURLLabel: String
    let apiKeyLabel: String
    let publicIPLabel: String
    let countryLabel: String
    let serverLabel: String
    let dhtLabel: String
    let diskFreeLabel: String
    let altSpeedLabel: String
    let etaLabel: String
    let seedsLeechersLabel: String
    let ratioLabel: String
    let eventFallback: String
    let openService: String
    let openFallback: String
    let sessions: String

    let total: String
    let pending: String
    let approved: String
    let available: String

    let sessionCreatedPrefix: String
    let sessionDeleted: String
    let oldestPendingApproved: String
    let oldestPendingDeclined: String
    let recentScanStarted: String
    let fullScanStarted: String
    let vpnRestartQueued: String
    let requestApproved: String
    let requestDeclined: String

    let showLess: String
    let showMore: (Int) -> String
}

extension ArrStrings {
    static func forLanguage(_ language: Language) -> ArrStrings {
        switch language {
        case .en:
            return ArrStrings(
                arrGroupTitle: "ARR Services",
                tutorialTitle: "Media ARR ready in minutes",
                tutorialBody: "Configure only the services you actually use.",
                tutorialStepConnect: "Add URL and credentials/API key for each service.",
                tutorialStepOpen: "Open each card for quick actions and status.",
                tutorialStepAutomations: "Backup and settings stay in sync.",
                tutorialActionConfigure: "Configure services",
                tutorialActionDismiss: "Hide guide",
                quickSetupTitle: "Unconfigured services",
                quickSetupSubtitle: "Add only what you really use.",
                addService: { "Add \($0)" },
                connection: "Connection",
                download: "Download",
                upload: "Upload",
                torrents: "Torrents",
                searchTorrents: "Search torrents",
                filterAll: "All",
                filterActive: "Active",
                filterDone: "Done",
                filterPaused: "Paused",
                recheck: "Recheck",
                reannounce: "Reannounce",
                deleteWithData: "Delete + Data",
                altLimitsToggled: "Alternative limits toggled",
                allResumed: "All torrents resumed",
                allPaused: "All torrents paused",
                torrentResumed: "Torrent resumed",
                torrentPaused: "Torrent paused",
                torrentDeleted: "Torrent deleted",
                torrentAndDataDeleted: "Torrent and data deleted",
                recheckStarted: "Recheck started",
                reannounceQueued: "Reannounce queued",
                radarrVersion: "Radarr Version",
                sonarrVersion: "Sonarr Version",
                lidarrVersion: "Lidarr Version",
                branch: "Branch",
                searchMissing: "Search Missing",
                refreshIndex: "Refresh Index",
                rssSync: "RSS Sync",
                rescan: "Rescan",
                downloadedScan: "Downloaded Scan",
                healthCheck: "Health Check",
                contentSearchTitle: "Content Search",
                contentSearchPlaceholder: { "Search in \($0)" },
                searchNow: "Search",
                clearSearch: "Clear",
                searchNoResults: "No results",
                searchStatusInLibrary: "In library",
                searchStatusMonitored: "Monitored",
                searchStatusUnmonitored: "Unmonitored",
                searchStatusEnded: "Ended",
                searchStatusPending: "Pending",
                searchStatusApproved: "Approved",
                searchStatusAvailable: "Available",
                searchStatusProcessing: "Processing",
                openDetails: "Open details",
                requestContent: "Request content",
                requestQueued: "Request sent",
                requestConfigurationTitle: { "Configure request for \($0)" },
                requestConfigurationMessage: "Choose the profile and folder to use for this request.",
                requestQualityProfile: "Quality profile",
                requestRootFolder: "Root folder",
                requestLanguageProfile: "Language profile",
                requestMetadataProfile: "Metadata profile",
                downloadingWithCount: { "Downloading (\($0))" },
                latestAdditions: "Latest Additions",
                tvSeriesLibrary: "TV Series Library",
                latestAlbums: "Latest Albums",
                recentHistory: "Recent History",
                health: "Health",
                upcoming: "Upcoming",
                noUpcoming: "No upcoming releases",
                movieSearchQueued: "Movie search queued",
                movieRefreshQueued: "Movie refresh queued",
                seriesSearchQueued: "Series search queued",
                seriesRefreshQueued: "Series refresh queued",
                albumSearchQueued: "Album search queued",
                artistRefreshQueued: "Artist refresh queued",
                rssSyncQueued: "RSS sync queued",
                rescanQueued: "Rescan queued",
                downloadedScanQueued: "Downloaded scan queued",
                healthCheckQueued: "Health check queued",
                requests: "Requests",
                approveOldestPending: "Approve oldest pending",
                declineOldestPending: "Decline oldest pending",
                recentMediaScan: "Recent media scan",
                fullMediaScan: "Full media scan",
                indexers: "Indexers",
                apps: "Apps",
                issues: "Issues",
                testIndexers: "Test Indexers",
                syncApps: "Sync Apps",
                indexerTestStarted: "Indexer test started",
                applicationSyncStarted: "Application sync started",
                subtitles: "Subtitles",
                vpn: "VPN",
                restartVpnTunnel: "Restart VPN tunnel",
                provider: "Provider",
                forwardedPort: "Forwarded Port",
                service: "Service",
                newSession: "New Session",
                sessionIds: "Session IDs",
                statusLabel: "Status",
                versionLabel: "Version",
                messageLabel: "Message",
                urlLabel: "URL",
                fallbackURLLabel: "Fallback URL",
                apiKeyLabel: "API Key",
                publicIPLabel: "Public IP",
                countryLabel: "Country",
                serverLabel: "Server",
                dhtLabel: "DHT Nodes",
                diskFreeLabel: "Disk Free",
                altSpeedLabel: "Alt Speed",
                etaLabel: "ETA",
                seedsLeechersLabel: "Seeds/Leechers",
                ratioLabel: "Ratio",
                eventFallback: "Event",
                openService: "Open Service",
                openFallback: "Open Fallback",
                sessions: "Sessions",
                total: "Total",
                pending: "Pending",
                approved: "Approved",
                available: "Available",
                sessionCreatedPrefix: "Session created:",
                sessionDeleted: "Session deleted",
                oldestPendingApproved: "Oldest pending request approved",
                oldestPendingDeclined: "Oldest pending request declined",
                recentScanStarted: "Recent scan started",
                fullScanStarted: "Full scan started",
                vpnRestartQueued: "VPN tunnel restart started",
                requestApproved: "Request approved",
                requestDeclined: "Request declined",
                showLess: "Show less",
                showMore: { "Show \($0) more" }
            )
        case .zh:
            return ArrStrings(
                arrGroupTitle: "ARR 服务",
                tutorialTitle: "Media ARR 数分钟内配置完成",
                tutorialBody: "只配置你实际使用的服务。",
                tutorialStepConnect: "为每个服务添加 URL 和凭据/API Key。",
                tutorialStepOpen: "打开卡片可查看快速操作和状态。",
                tutorialStepAutomations: "备份和设置保持同步。",
                tutorialActionConfigure: "配置服务",
                tutorialActionDismiss: "隐藏指南",
                quickSetupTitle: "未配置的服务",
                quickSetupSubtitle: "只添加你真正需要的服务。",
                addService: { "添加 \($0)" },
                connection: "连接",
                download: "下载",
                upload: "上传",
                torrents: "种子",
                searchTorrents: "搜索种子",
                filterAll: "全部",
                filterActive: "活跃",
                filterDone: "完成",
                filterPaused: "暂停",
                recheck: "重新检查",
                reannounce: "重新宣告",
                deleteWithData: "删除+数据",
                altLimitsToggled: "备用限制已切换",
                allResumed: "所有种子已恢复",
                allPaused: "所有种子已暂停",
                torrentResumed: "种子已恢复",
                torrentPaused: "种子已暂停",
                torrentDeleted: "种子已删除",
                torrentAndDataDeleted: "种子和数据已删除",
                recheckStarted: "重新检查已启动",
                reannounceQueued: "重新宣告已排队",
                radarrVersion: "Radarr 版本",
                sonarrVersion: "Sonarr 版本",
                lidarrVersion: "Lidarr 版本",
                branch: "分支",
                searchMissing: "搜索缺失",
                refreshIndex: "刷新索引",
                rssSync: "RSS 同步",
                rescan: "重新扫描",
                downloadedScan: "已下载扫描",
                healthCheck: "健康检查",
                contentSearchTitle: "内容搜索",
                contentSearchPlaceholder: { "在 \($0) 中搜索" },
                searchNow: "搜索",
                clearSearch: "清除",
                searchNoResults: "无结果",
                searchStatusInLibrary: "已入库",
                searchStatusMonitored: "已监控",
                searchStatusUnmonitored: "未监控",
                searchStatusEnded: "已结束",
                searchStatusPending: "待处理",
                searchStatusApproved: "已批准",
                searchStatusAvailable: "可用",
                searchStatusProcessing: "处理中",
                openDetails: "打开详情",
                requestContent: "请求内容",
                requestQueued: "请求已发送",
                requestConfigurationTitle: { "配置 \($0) 的请求" },
                requestConfigurationMessage: "选择用于此请求的配置文件和文件夹。",
                requestQualityProfile: "质量配置",
                requestRootFolder: "根文件夹",
                requestLanguageProfile: "语言配置",
                requestMetadataProfile: "元数据配置",
                downloadingWithCount: { "下载中 (\($0))" },
                latestAdditions: "最新添加",
                tvSeriesLibrary: "电视剧库",
                latestAlbums: "最新专辑",
                recentHistory: "最近历史",
                health: "健康",
                upcoming: "即将推出",
                noUpcoming: "暂无即将发布的版本",
                movieSearchQueued: "电影搜索已排队",
                movieRefreshQueued: "电影刷新已排队",
                seriesSearchQueued: "剧集搜索已排队",
                seriesRefreshQueued: "剧集刷新已排队",
                albumSearchQueued: "专辑搜索已排队",
                artistRefreshQueued: "艺术家刷新已排队",
                rssSyncQueued: "RSS 同步已排队",
                rescanQueued: "重新扫描已排队",
                downloadedScanQueued: "已下载扫描已排队",
                healthCheckQueued: "健康检查已排队",
                requests: "请求",
                approveOldestPending: "批准最早待处理",
                declineOldestPending: "拒绝最早待处理",
                recentMediaScan: "最近媒体扫描",
                fullMediaScan: "完整媒体扫描",
                indexers: "索引器",
                apps: "应用",
                issues: "问题",
                testIndexers: "测试索引器",
                syncApps: "同步应用",
                indexerTestStarted: "索引器测试已启动",
                applicationSyncStarted: "应用同步已启动",
                subtitles: "字幕",
                vpn: "VPN",
                restartVpnTunnel: "重启 VPN 隧道",
                provider: "提供商",
                forwardedPort: "转发端口",
                service: "服务",
                newSession: "新会话",
                sessionIds: "会话 ID",
                statusLabel: "状态",
                versionLabel: "版本",
                messageLabel: "消息",
                urlLabel: "URL",
                fallbackURLLabel: "备用 URL",
                apiKeyLabel: "API 密钥",
                publicIPLabel: "公网 IP",
                countryLabel: "国家",
                serverLabel: "服务器",
                dhtLabel: "DHT 节点",
                diskFreeLabel: "磁盘可用",
                altSpeedLabel: "备用速度",
                etaLabel: "预计时间",
                seedsLeechersLabel: "做种/下载",
                ratioLabel: "分享率",
                eventFallback: "事件",
                openService: "打开服务",
                openFallback: "打开备用",
                sessions: "会话",
                total: "总计",
                pending: "待处理",
                approved: "已批准",
                available: "可用",
                sessionCreatedPrefix: "会话已创建：",
                sessionDeleted: "会话已删除",
                oldestPendingApproved: "最早待处理请求已批准",
                oldestPendingDeclined: "最早待处理请求已拒绝",
                recentScanStarted: "最近扫描已启动",
                fullScanStarted: "完整扫描已启动",
                vpnRestartQueued: "VPN 隧道重启已启动",
                requestApproved: "请求已批准",
                requestDeclined: "请求已拒绝",
                showLess: "收起",
                showMore: { "显示其余 \($0) 项" }
            )
        }
    }
}

extension Localizer {
    var arr: ArrStrings {
        ArrStrings.forLanguage(language)
    }
}
