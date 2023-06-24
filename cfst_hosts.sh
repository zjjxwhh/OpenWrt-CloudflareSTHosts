#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
# --------------------------------------------------------------
#	[修改脚本信息]
#	作者: Hervey
#	修改说明: 支持同时修改 Hosts 中的 IPv4 及 IPv6 地址
# --------------------------------------------------------------
#	[原始脚本信息]
#	项目: CloudflareSpeedTest 自动更新 Hosts
#	版本: 1.0.4
#	作者: XIU2
#	项目: https://github.com/XIU2/CloudflareSpeedTest
# --------------------------------------------------------------

_CHECK() {
	while true
		do
		if [[ ! -e "nowip_hosts.txt" ]]; then
			echo -e "该脚本的作用为 CloudflareST 测速后获取最快 IP 并替换 Hosts 中的 Cloudflare CDN IP。\n使用前请先阅读：https://github.com/XIU2/CloudflareSpeedTest/issues/42#issuecomment-768273848"
			echo -e "第一次使用，请先将 Hosts 中所有 Cloudflare CDN IP 统一改为一个 IP。"
			read -e -p "输入该 Cloudflare CDN IPv4 并回车（后续不再需要该步骤）：" NOWIPV4
			if [[ ! -z "${NOWIPV4}" ]]; then
				echo ${NOWIPV4} > nowip_hosts.txt
				break
			else
				echo "该 IPv4 不能是空！"
			fi

			read -e -p "输入该 Cloudflare CDN IPv6 并回车（后续不再需要该步骤）：" NOWIPV6
			if [[ ! -z "${NOWIPV6}" ]]; then
				echo ${NOWIPV6} > nowip_hosts.txt
				break
			else
				echo "该 IPv6 不能是空！"
			fi
		else
			break
		fi
	done
}

_UPDATE() {
	echo -e "开始测速..."
	NOWIPV4=$(head -1 nowip_hosts.txt)
	NOWIPV6=$(tail -1 nowip_hosts.txt)

	# 这里可以自己添加、修改 CloudflareST 的运行参数
	cdnspeedtest -f "ip.txt" -o "result_hosts_ipv4.txt"

	# 如果需要 "找不到满足条件的 IP 就一直循环测速下去"，那么可以将下面的两个 exit 0 改为 _UPDATE 即可
	[[ ! -e "result_hosts_ipv4.txt" ]] && echo "CloudflareST 测速结果 IPv4 数量为 0，跳过下面步骤..." && exit 0

	cdnspeedtest -f "ipv6.txt" -o "result_hosts_ipv6.txt"
	[[ ! -e "result_hosts_ipv6.txt" ]] && echo "CloudflareST 测速结果 IPv6 数量为 0，跳过下面步骤..." && exit 0

	# 下面这行代码是 "找不到满足条件的 IP 就一直循环测速下去" 才需要的代码
	# 考虑到当指定了下载速度下限，但一个满足全部条件的 IP 都没找到时，CloudflareST 就会输出所有 IP 结果
	# 因此当你指定 -sl 参数时，需要移除下面这段代码开头的 # 井号注释符，来做文件行数判断（比如下载测速数量：10 个，那么下面的值就设在为 11）
	#[[ $(cat result_hosts.txt|wc -l) > 11 ]] && echo "CloudflareST 测速结果没有找到一个完全满足条件的 IP，重新测速..." && _UPDATE

	BESTIPV4=$(sed -n "2,1p" result_hosts_ipv4.txt | awk -F, '{print $1}')
	BESTIPV6=$(sed -n "2,1p" result_hosts_ipv6.txt | awk -F, '{print $1}')

	echo "开始备份 Hosts 文件（myhosts_backup）..."
	\cp -f /etc/myhosts /etc/CloudflareST/myhosts_backup

	if [[ -z "${BESTIPV4}" ]]; then
		echo "CloudflareST 测速结果 IPv4 数量为 0，跳过下面步骤..."
	else
		sed -i 's/'${NOWIPV4}'/'${BESTIPV4}'/g' nowip_hosts.txt
		echo -e "\n旧 IPv4 为 ${NOWIPV4}\n新 IPv4 为 ${BESTIPV4}\n"

		echo -e "开始替换 IPv4..."
		sed -i 's/'${NOWIPV4}'/'${BESTIPV4}'/g' /etc/myhosts
		echo -e "完成替换 IPv4..."
	fi

	if [[ -z "${BESTIPV6}" ]]; then
		echo "CloudflareST 测速结果 IPv6 数量为 0，跳过下面步骤..."
	else
		sed -i 's/'${NOWIPV6}'/'${BESTIPV6}'/g' nowip_hosts.txt
		echo -e "\n旧 IPv6 为 ${NOWIPV6}\n新 IPv6 为 ${BESTIPV6}\n"

		echo -e "开始替换 IPv6..."
		sed -i 's/'${NOWIPV6}'/'${BESTIPV6}'/g' /etc/myhosts
		echo -e "完成替换 IPv6..."
	fi

	echo -e "开始重启 dnsmasq 服务..."
	/etc/init.d/dnsmasq restart
	echo -e "完成重启 dnsmasq 服务..."
}

_CHECK
_UPDATE