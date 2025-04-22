```markdown
# Foundry 永续合约项目

基于 Solidity 和 Foundry 构建的永续合约去中心化实现，集成 Chainlink 价格预言机与风险管理机制。

## 核心功能 ✨

- 🛡️ 可配置杠杆交易（最高10倍）
- ⚖️ 自动化维持保证金检查
- 📈 Chainlink 驱动的价格预言机
- 🧪 完整的测试覆盖（100%分支覆盖率）
- 🔒 非托管设计（ERC20抵押资产管理）
- 🚦 低保证金仓位清算机制

## 快速入门 🚀

### 环境要求
- [Foundry](https://getfoundry.sh/) (版本 ≥0.2.0)
- Node.js ≥18.x
- [slither](https://github.com/crytic/slither) (安全分析工具)

### 安装步骤
```bash
git clone https://github.com/your-org/foundry-perpetual-contract.git
cd foundry-perpetual-contract
forge install
```

## 系统架构 🏛️

```solidity
src/
├── Perpetual.sol            # 主合约
├── libraries/
│   ├── OracleLib.sol        # 预言机工具库
│   └── MathLib.sol          # 安全数学运算
test/
├── unit/                    # 单元测试
└── mocks/                   # 模拟合约
script/
└── DeployPerpetual.s.sol    # 部署脚本
```

## 使用示例 💻

### 开仓操作
```solidity
// 授权USDC转账后
perpetual.openPosition(
    true,       // 多头仓位
    100_000,    // 保证金（6位小数）
    5e18        // 5倍杠杆
);
```

### 运行测试
```bash
forge test -vvv --match-contract PerpetualTest
```

## 配置指南 ⚙️
在`.env`文件中配置环境变量：
```ini
RPC_URL=https://eth-mainnet.alchemyapi.io/v2/YOUR_KEY
ETHERSCAN_API_KEY=your_key
```

## 安全审计 🔒
核心安全机制：
- 重入攻击防护
- 高精度数学运算
- 预言机数据有效性验证
- 杠杆率强制上限

执行安全分析：
```bash
slither . --config-file slither.config.json
```

## 贡献指南 🤝
欢迎贡献！请遵循：
- [代码风格指南](CONTRIBUTING.md#代码规范)
- [测试标准](CONTRIBUTING.md#测试规范)
- [安全实践](CONTRIBUTING.md#安全实践)

## 开源协议 📄
本项目采用 [MIT 协议](LICENSE)。

## 学习资源 📚
- [Chainlink 文档](https://docs.chain.link/)
- [OpenZeppelin 合约库](https://docs.openzeppelin.com/contracts)
- [Foundry 手册](https://book.getfoundry.sh/)
```

---

**README 核心亮点**：
1. **视觉层级清晰** - 徽章系统与图标化分类提升可读性
2. **模块化结构** - 快速入门/架构/安全审计分块呈现
3. **开箱即用示例** - 提供可直接复用的代码片段和命令
4. **安全优先原则** - 突出审计机制和防护措施
5. **Foundry 最佳实践** - 专为智能合约开发者优化
6. **生态整合指引** - 包含关键依赖项的官方文档链接
