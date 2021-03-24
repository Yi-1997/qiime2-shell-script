#！/bin/bash
grep 'length_[0-9]_' $1.fasta >> $1_cut_inf_tmp.txt	#查找0-9序列长度输入到cut_inf_tmp文件
grep 'length_[0-9][0-9]_' $1.fasta >> $1_cut_inf_tmp.txt	#查找10-99序列长度输入到cut_inf_tmp文件
grep 'length_[0-4][0-9][0-9]_' $1.fasta >> $1_cut_inf_tmp.txt	#查找100-499序列长度输入到cut_inf_tmp文件
grep 'length_500_' $1.fasta >> $1_cut_inf_tmp.txt	#查找500序列长度输入到cut_inf_tmp文件
grep 'cov_[0-9]\.' $1.fasta >> $1_cut_inf_tmp.txt	#查找覆盖率低于10的序列输入到cut_inf_tmp文件
cat $1_cut_inf_tmp.txt | sort | uniq > $1_cut_inf.txt	#剔除重复序列，保留唯一值输入到$1_cut_inf文件
cat $1_cut_inf.txt | while read line	#逐行读入txt文件
do
number=$(echo $line | cut -d '_' -f 4)	#使用cut根据_分割每一行，读取第四个参数即序列长度，并赋值到变量number
echo $number	#打印变量number
num=$(echo $line | cut -d '_' -f 2)	#使用cut根据_分割每一行，读取第二个参数即序列编号，并赋值到变量num
echo $num	#打印变量num
let remainder=number%60	#序列长度变量number除60取余，并把余数赋值给remainder
echo ${remainder}	#打印remainder
if [ "${remainder}" == "0" ]; then	#判断余数是否为零
	let cut_row=number/60	#为零，则cut_row赋值为序列长度变量除60
else
	let cut_row=number/60+1	#否则，cut_row赋值为序列长度除以60加1
fi
echo $cut_row	#打印cut_row
sed -i "/NODE_${num}_length_${number}/,+${cut_row}d" $1.fasta	#根据序列长度变量number和序列变量num匹配序列编号，同时剔除不符合的序列。
echo $line;	#打印本次读取的序列信息
done
rm $1_cut_inf_tmp.txt	#删除cut_inf_tmp临时文件
