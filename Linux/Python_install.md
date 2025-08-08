
# Python 3.13 源码编译安装指南

本指南将引导您从源码编译安装 Python 3.13，并进行必要的配置。


## 1. 安装编译依赖

```bash
sudo apt update
sudo apt install -y build-essential zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libssl-dev libreadline-dev libffi-dev libsqlite3-dev wget libbz2-dev
```

## 2. 下载并编译 Python 3.13

### 进入临时目录
```bash
cd /tmp
```

### 一键安装编译依赖并编译 Python 3.13.6
```bash
apt update && apt install -y build-essential libssl-dev libffi-dev libsqlite3-dev libbz2-dev libreadline-dev libncurses5-dev libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev liblzma-dev && cd /tmp && wget https://www.python.org/ftp/python/3.13.6/Python-3.13.6.tgz && tar -xzf Python-3.13.6.tgz && cd Python-3.13.6 && ./configure --enable-optimizations --prefix=/usr/local && make -j$(nproc) && make altinstall
```

## 3. 安装 pip

```bash
# 使用内置模块安装pip
/usr/local/bin/python3.13 -m ensurepip --upgrade

# 或者手动安装pip
curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
/usr/local/bin/python3.13 get-pip.py
rm get-pip.py
```

## 4. 创建符号链接和配置环境

### 创建符号链接
```bash
ln -sf /usr/local/bin/python3.13 /usr/local/bin/python3
ln -sf /usr/local/bin/python3.13 /usr/local/bin/python
ln -sf /usr/local/bin/pip3.13 /usr/local/bin/pip3
```

### 更新 PATH 环境变量
```bash
echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

## 5. 验证安装

```bash
python --version && python3 --version && python3.13 --version && pip --version
which python3.13 && which python3
```

## 6. 安装常用包

```bash
/usr/local/bin/python3.13 -m pip install --upgrade pip
/usr/local/bin/python3.13 -m pip install setuptools wheel virtualenv
python -m pip install --root-user-action=ignore requests numpy pandas
```

## 7. 清理安装文件

```bash
cd / && rm -rf /tmp/Python-3.13.6*
```

## 8. 测试新特性

```bash
python -c "
print('🎉 Python 3.13 ready!')
import sys
print(f'Version: {sys.version_info}')
print('New features include improved error messages, better performance, and more!')
"
```

## 9. 其他操作

### 从 requirements.txt 安装包
```bash
/usr/local/bin/python3.13 -m pip install -r requirements.txt --root-user-action=ignore
```

## 现在你可以开始使用 Python 3.13 了！🐍✨
