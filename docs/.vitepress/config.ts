import { defineConfig } from 'vitepress'

const repo = process.env.GITHUB_REPOSITORY
const base =
  process.env.VITEPRESS_BASE
  ?? (process.env.GITHUB_ACTIONS && repo ? `/${repo.split('/')[1]}/` : '/')

const github = 'https://github.com/openalon-org/herdr-bar'

function sidebar(prefix: string, t: {
  start: string
  install: string
  prereq: string
  steps: string
  firstRun: string
  demo: string
  usage: string
  menubar: string
  dashboard: string
  keyboard: string
  focus: string
  config: string
  file: string
  colors: string
  hideIdle: string
  hotkey: string
  deeper: string
  architecture: string
  layers: string
  dataFlow: string
  discovery: string
  focusRaiser: string
  status: string
  states: string
  priority: string
  glance: string
  grouping: string
  protocol: string
  transport: string
  methods: string
  events: string
  identity: string
  invariants: string
  development: string
  map: string
  tests: string
  run: string
  docs: string
}) {
  return [
    {
      text: t.start,
      items: [
        {
          text: t.install,
          link: `${prefix}/guide/installation`,
          collapsed: true,
          items: [
            { text: t.prereq, link: `${prefix}/guide/installation#prerequisites` },
            { text: t.steps, link: `${prefix}/guide/installation#steps` },
            { text: t.firstRun, link: `${prefix}/guide/installation#first-run` },
            { text: t.demo, link: `${prefix}/guide/installation#demo` },
          ],
        },
        {
          text: t.usage,
          link: `${prefix}/guide/usage`,
          collapsed: true,
          items: [
            { text: t.menubar, link: `${prefix}/guide/usage#menubar` },
            { text: t.dashboard, link: `${prefix}/guide/usage#dashboard` },
            { text: t.keyboard, link: `${prefix}/guide/usage#keyboard` },
            { text: t.focus, link: `${prefix}/guide/usage#focus` },
          ],
        },
        {
          text: t.config,
          link: `${prefix}/guide/configuration`,
          collapsed: true,
          items: [
            { text: t.file, link: `${prefix}/guide/configuration#file` },
            { text: t.colors, link: `${prefix}/guide/configuration#colors` },
            { text: t.hideIdle, link: `${prefix}/guide/configuration#hide-idle` },
            { text: t.hotkey, link: `${prefix}/guide/configuration#hotkey` },
          ],
        },
      ],
    },
    {
      text: t.deeper,
      items: [
        {
          text: t.architecture,
          link: `${prefix}/guide/architecture`,
          collapsed: true,
          items: [
            { text: t.layers, link: `${prefix}/guide/architecture#layers` },
            { text: t.dataFlow, link: `${prefix}/guide/architecture#data-flow` },
            { text: t.discovery, link: `${prefix}/guide/architecture#discovery` },
            { text: t.focusRaiser, link: `${prefix}/guide/architecture#focus-raiser` },
          ],
        },
        {
          text: t.status,
          link: `${prefix}/guide/status`,
          collapsed: true,
          items: [
            { text: t.states, link: `${prefix}/guide/status#states` },
            { text: t.priority, link: `${prefix}/guide/status#priority` },
            { text: t.glance, link: `${prefix}/guide/status#glance` },
            { text: t.grouping, link: `${prefix}/guide/status#grouping` },
          ],
        },
        {
          text: t.protocol,
          link: `${prefix}/guide/protocol`,
          collapsed: true,
          items: [
            { text: t.transport, link: `${prefix}/guide/protocol#transport` },
            { text: t.methods, link: `${prefix}/guide/protocol#methods` },
            { text: t.events, link: `${prefix}/guide/protocol#events` },
            { text: t.identity, link: `${prefix}/guide/protocol#identity` },
          ],
        },
        { text: t.invariants, link: `${prefix}/guide/invariants` },
        {
          text: t.development,
          link: `${prefix}/guide/development`,
          collapsed: true,
          items: [
            { text: t.map, link: `${prefix}/guide/development#map` },
            { text: t.tests, link: `${prefix}/guide/development#tests` },
            { text: t.run, link: `${prefix}/guide/development#run` },
            { text: t.docs, link: `${prefix}/guide/development#docs` },
          ],
        },
      ],
    },
  ]
}

export default defineConfig({
  ignoreDeadLinks: false,
  base,
  title: 'herdr-bar',
  description: 'macOS menu-bar companion for Herdr: see every coding agent, jump to the one that needs you.',
  head: [
    ['link', { rel: 'icon', type: 'image/svg+xml', href: `${base.replace(/\/$/, '')}/herdr-bar-icon.svg` }],
  ],

  locales: {
    root: {
      label: 'English',
      lang: 'en-US',
      themeConfig: {
        nav: [
          { text: 'Start', link: '/guide/installation' },
          { text: 'Use', link: '/guide/usage' },
          { text: 'Architecture', link: '/guide/architecture' },
          { text: 'GitHub', link: github },
        ],
        sidebar: { '/guide/': sidebar('', {
          start: 'Start',
          install: 'Install',
          prereq: 'Prerequisites',
          steps: 'Install',
          firstRun: 'First launch',
          demo: 'Demo mode',
          usage: 'Usage',
          menubar: 'Menu bar',
          dashboard: 'Dashboard',
          keyboard: 'Keyboard',
          focus: 'Focus',
          config: 'Configuration',
          file: 'Config file',
          colors: 'Status colors',
          hideIdle: 'Notification mode',
          hotkey: 'Global hotkey',
          deeper: 'Deeper',
          architecture: 'Architecture',
          layers: 'Layers',
          dataFlow: 'Data flow',
          discovery: 'Discovery',
          focusRaiser: 'Focus raiser',
          status: 'Status model',
          states: 'Five states',
          priority: 'Priority',
          glance: 'Menu-bar glance',
          grouping: 'Grouping',
          protocol: 'Protocol',
          transport: 'Transport',
          methods: 'Methods',
          events: 'Events',
          identity: 'Identity',
          invariants: 'Invariants',
          development: 'Development',
          map: 'Repository map',
          tests: 'Tests',
          run: 'Run locally',
          docs: 'Docs site',
        }) },
        outline: { level: [2, 3], label: 'On this page' },
        docFooter: { prev: 'Previous', next: 'Next' },
        lastUpdated: { text: 'Last updated' },
      },
    },
    zh: {
      label: '简体中文',
      lang: 'zh-CN',
      description: 'macOS 菜单栏上的 Herdr 伴侣：一眼看到每个 coding agent，跳到最需要你的那个。',
      themeConfig: {
        nav: [
          { text: '开始', link: '/zh/guide/installation' },
          { text: '使用', link: '/zh/guide/usage' },
          { text: '架构', link: '/zh/guide/architecture' },
          { text: 'GitHub', link: github },
        ],
        sidebar: { '/zh/guide/': sidebar('/zh', {
          start: '开始',
          install: '安装',
          prereq: '前提条件',
          steps: '安装',
          firstRun: '首次启动',
          demo: '演示模式',
          usage: '使用',
          menubar: '菜单栏',
          dashboard: '仪表盘',
          keyboard: '键盘',
          focus: '聚焦',
          config: '配置',
          file: '配置文件',
          colors: '状态颜色',
          hideIdle: '通知模式',
          hotkey: '全局快捷键',
          deeper: '深入',
          architecture: '架构',
          layers: '分层',
          dataFlow: '数据流',
          discovery: '发现与聚合',
          focusRaiser: '聚焦宿主',
          status: '状态模型',
          states: '五种状态',
          priority: '优先级',
          glance: '菜单栏一览',
          grouping: '分组与排序',
          protocol: '协议',
          transport: '传输',
          methods: '方法',
          events: '事件',
          identity: '身份',
          invariants: '不变量',
          development: '开发',
          map: '仓库地图',
          tests: '测试',
          run: '本地运行',
          docs: '文档站',
        }) },
        outline: { level: [2, 3], label: '目录' },
        docFooter: { prev: '上一页', next: '下一页' },
        lastUpdated: { text: '最后更新' },
      },
    },
  },

  themeConfig: {
    logo: '/herdr-bar-icon.svg',
    socialLinks: [{ icon: 'github', link: github }],
    search: { provider: 'local' },
  },

  lastUpdated: true,
})
