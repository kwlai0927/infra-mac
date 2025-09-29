# Lima K3s 管理指令

.PHONY: help lima-install k3s-install k3s-start k3s-stop k3s-config k3s-status k3s-clean

help: ## 顯示所有可用指令
	@echo "🚀 Lima K3s 管理指令"
	@echo ""
	@echo "📦 安裝指令："
	@echo "  lima-install    安裝 Lima"
	@echo "  k3s-install     安裝 K3s 環境"
	@echo ""
	@echo "🔧 運行指令："
	@echo "  k3s-start       啟動 K3s 實例"
	@echo "  k3s-stop        停止 K3s 實例"
	@echo "  k3s-config      更新 kubeconfig"
	@echo ""
	@echo "📊 狀態指令："
	@echo "  k3s-status      查看 K3s 狀態"
	@echo "  k3s-clean       清理 K3s 實例"
	@echo ""
	@echo "💡 使用範例："
	@echo "  make lima-install && make k3s-install && make k3s-start && make k3s-config"

# Lima 安裝
lima-install: ## 安裝 Lima
	@echo "🚀 安裝 Lima..."
	sudo ./lima/install.sh

# K3s 安裝
k3s-install: ## 安裝 K3s 環境
	@echo "🚀 安裝 K3s 環境..."
	chmod +x k3s/install-k3s.sh
	sudo ./k3s/install-k3s.sh

# K3s 啟動
k3s-start: ## 啟動 K3s 實例
	@echo "🚀 啟動 K3s 實例..."
	chmod +x k3s/start-k3s.sh
	./k3s/start-k3s.sh

# K3s 停止
k3s-stop: ## 停止 K3s 實例
	@echo "🛑 停止 K3s 實例..."
	chmod +x k3s/stop-k3s.sh
	./k3s/stop-k3s.sh

# K3s 配置
k3s-config: ## 更新 kubeconfig
	@echo "🔧 更新 kubeconfig..."
	chmod +x k3s/update-kubeconfig.sh
	./k3s/update-kubeconfig.sh

# K3s 狀態
k3s-status: ## 查看 K3s 狀態
	@echo "📊 K3s 狀態："
	@limactl list | grep k3s || echo "K3s 實例不存在"

# K3s 清理
k3s-clean: ## 清理 K3s 實例
	@echo "🧹 清理 K3s 實例..."
	@if limactl list | grep -q "k3s"; then \
		echo "刪除 K3s 實例..."; \
		sudo limactl delete k3s; \
		echo "✅ K3s 實例已刪除"; \
	else \
		echo "⚠️  K3s 實例不存在"; \
	fi
