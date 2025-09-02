# Core Management Commands

stop:
	@echo "🛑 Stopping ERP Suite infrastructure..."
	@echo "📋 Stopping all Docker Compose services..."
	@docker compose down --remove-orphans --volumes --timeout 30 2>/dev/null || true
	@echo "🔍 Killing any remaining ERP Suite containers..."
	@docker ps -a --filter "name=erp-suite" --format "{{.Names}}" | xargs -r docker rm -f 2>/dev/null || true
	@echo "🧹 Cleaning up orphaned containers..."
	@docker container prune -f 2>/dev/null || true
	@echo "🌐 Cleaning up unused networks..."
	@docker network prune -f 2>/dev/null || true
	@echo "🔍 Checking for processes still using ERP ports..."
	@OS=$$(uname); \
	ports="5432 27017 6379 6333 9092 9200 5601 4000 8500 3001 8081 8082 8083 8084"; \
	killed_processes=0; \
	for port in $$ports; do \
		if [ "$$OS" = "Darwin" ]; then \
			pids=$$(lsof -ti :$$port 2>/dev/null || true); \
		elif [ "$$OS" = "Linux" ]; then \
			pids=$$(ss -tlnp | grep ":$$port " | sed 's/.*pid=\([0-9]*\).*/\1/' 2>/dev/null || true); \
		fi; \
		if [ -n "$$pids" ]; then \
			echo "⚠️  Found processes using port $$port: $$pids"; \
			for pid in $$pids; do \
				if ps -p $$pid > /dev/null 2>&1; then \
					echo "🔪 Killing process $$pid on port $$port"; \
					kill -9 $$pid 2>/dev/null || true; \
					killed_processes=$$((killed_processes + 1)); \
				fi; \
			done; \
		fi; \
	done; \
	if [ $$killed_processes -gt 0 ]; then \
		echo "⚡ Killed $$killed_processes processes"; \
		sleep 2; \
	fi
	@echo "🔍 Final port check..."
	@OS=$$(uname); \
	ports="5432 27017 6379 6333 9092 9200 5601 4000 8500 3001 8081 8082 8083 8084"; \
	still_in_use=0; \
	for port in $$ports; do \
		port_in_use=false; \
		if [ "$$OS" = "Darwin" ]; then \
			if lsof -i :$$port > /dev/null 2>&1; then \
				port_in_use=true; \
			fi; \
		elif [ "$$OS" = "Linux" ]; then \
			if ss -tuln | grep ":$$port " > /dev/null 2>&1; then \
				port_in_use=true; \
			fi; \
		fi; \
		if [ "$$port_in_use" = "true" ]; then \
			echo "⚠️  Port $$port is still in use"; \
			still_in_use=$$((still_in_use + 1)); \
		fi; \
	done; \
	if [ $$still_in_use -eq 0 ]; then \
		echo "✅ All ERP Suite ports are now free!"; \
	else \
		echo "⚠️  $$still_in_use ports are still in use (may be system services)"; \
	fi
	@echo "✅ ERP Suite infrastructure stopped and ports freed!"
