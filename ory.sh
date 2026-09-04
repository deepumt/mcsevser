#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 全局变量
DO_CLEAN=0
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="./sig_report_${TIMESTAMP}.log"
total_jar=0
sig_found_count=0
declare -a broken_jars=()

usage(){
    echo -e "${GREEN}Jar签名清理&扫描一体工具(支持多层嵌套jar)${NC}"
    echo "用法:"
    echo "  $0              # 仅扫描，输出报告，不修改文件"
    echo "  $0 --clean      # 执行深度清理，清理完成自动复核扫描输出报告"
    echo ""
    echo "依赖: pkg install zip unzip"
    exit 1
}

# 清理函数：递归处理jar，原地删除签名
process_jar(){
    local jarfile="$1"
    [[ -f "$jarfile" ]] || return 0
    echo ">>> 清理Jar: $jarfile"

    zip -d "$jarfile" "META-INF/*.SF" "META-INF/*.RSA" "META-INF/*.DSA" 2>/dev/null || true

    local tmpdir
    tmpdir=$(mktemp -d -t jarclean.XXXXXX)
    trap 'rm -rf "$tmpdir"' RETURN

    if ! unzip -q -o "$jarfile" -d "$tmpdir" 2>/dev/null; then
        echo -e "    ${YELLOW}⚠️损坏无法解压，跳过${NC}: $jarfile"
        rm -rf "$tmpdir"
        return 0
    fi

    # 递归处理内嵌jar
    find "$tmpdir" -type f -iname "*.jar" -print0 | while IFS= read -r -d '' innerjar; do
        process_jar "$innerjar"
    done

    # 删除签名文件
    find "$tmpdir" -type f \( -iname "*.SF" -o -iname "*.RSA" -o -iname "*.DSA" \) -delete

    rm -f "$jarfile"
    pushd "$tmpdir" >/dev/null
    zip -q -r "$jarfile" ./*
    popd >/dev/null

    rm -rf "$tmpdir"
    trap - RETURN
}

# 扫描函数：递归扫描嵌套jar，写入报告
scan_jar(){
    local jarpath="$1"
    local parent_chain="$2"
    [[ -f "$jarpath" ]] || return 0
    ((total_jar++))

    local tmpdir
    tmpdir=$(mktemp -d -t jarscan.XXXXXX)
    trap 'rm -rf "$tmpdir"' RETURN

    if ! unzip -q -o "$jarpath" -d "$tmpdir" 2>/dev/null; then
        echo -e "${YELLOW}[WARN] 损坏无法解压: ${jarpath}${NC}"
        broken_jars+=("${parent_chain}${jarpath}")
        echo "[BROKEN] ${parent_chain}${jarpath}" >> "$REPORT_FILE"
        rm -rf "$tmpdir"
        return 0
    fi

    sig_entries=$(unzip -l "$jarpath" 2>/dev/null | grep -E '\.(SF|RSA|DSA)$' || true)
    if [[ -n "$sig_entries" ]];then
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            ((sig_found_count++))
            local full_entry="${parent_chain}${jarpath} | ${line}"
            echo -e "${RED}[SIG_FOUND] ${full_entry}${NC}"
            echo "[SIG] ${full_entry}" >> "$REPORT_FILE"
        done <<< "$sig_entries"
    fi

    # 递归扫描内部jar
    find "$tmpdir" -type f -iname "*.jar" -print0 | while IFS= read -r -d '' innerjar; do
        rel_inner="${innerjar#${tmpdir}/}"
        new_chain="${parent_chain}${jarpath}!"
        scan_jar "$innerjar" "$new_chain"
    done

    rm -rf "$tmpdir"
    trap - RETURN
}

do_scan(){
    # 重置统计
    total_jar=0
    sig_found_count=0
    broken_jars=()

    cat > "$REPORT_FILE" <<EOF
============================================
Jar签名扫描报告（支持多层嵌套Jar）
扫描开始时间: $(date)
工作目录: $(pwd)
查找目标: META‑INF/*.SF *.RSA *.DSA
============================================

EOF

    echo -e "${GREEN}===== 开始深度扫描Jar签名 =====${NC}"
    echo "报告输出文件: ${REPORT_FILE}"
    echo ""

    find . -type f -iname "*.jar" -print0 | while IFS= read -r -d '' topjar; do
        scan_jar "$topjar" ""
    done

    {
    echo ""
    echo "============================================"
    echo "扫描统计汇总"
    echo "总扫描Jar数量: ${total_jar}"
    echo "发现签名条目数: ${sig_found_count}"
    echo "损坏Jar数量: ${#broken_jars[@]}"
    if [[ ${#broken_jars[@]} -gt 0 ]];then
        echo "损坏Jar列表:"
        for b in "${broken_jars[@]}";do echo " - $b"; done
    fi
    echo "扫描结束时间: $(date)"
    echo "============================================"
    } >> "$REPORT_FILE"

    echo ""
    echo -e "${GREEN}✅扫描完成${NC}"
    echo "总扫描Jar: ${total_jar}"
    echo "检测到签名条目: ${sig_found_count}"
    echo "损坏无法解析Jar: ${#broken_jars[@]}"
    echo "完整报告保存至: ${REPORT_FILE}"
    if [[ $sig_found_count -gt 0 ]];then
        echo -e "${RED}⚠️ 存在残留签名${NC}"
    else
        echo -e "${GREEN}✅未检测到SF/RSA/DSA签名文件${NC}"
    fi
}

main(){
    # 参数解析
    if [[ $# -ge 1 ]];then
        if [[ "$1" == "--clean" ]];then
            DO_CLEAN=1
        else
            usage
        fi
    fi

    # 依赖检查
    if ! command -v zip &> /dev/null || ! command -v unzip &> /dev/null; then
        echo -e "${RED}缺少依赖，请执行 pkg install zip unzip${NC}"
        exit 1
    fi

    if [[ ${DO_CLEAN} -eq 1 ]];then
        echo -e "${GREEN}===== 执行深度清理（多层嵌套Jar）=====${NC}"
        find . -type f -iname "*.jar" -print0 | while IFS= read -r -d '' topjar; do
            process_jar "$topjar"
        done
        echo ""
        echo -e "${GREEN}✅清理完成，自动启动复核扫描${NC}"
        echo "----------------------------------------"
    fi

    # 执行扫描（清理后自动复核；直接运行就只是扫描）
    do_scan
}

main "$@"