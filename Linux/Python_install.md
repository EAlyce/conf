
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

### 一键安装编译依赖并编译
`PYTHON_VERSION="3.13.7"` 可自定义版本
```bash
PYTHON_VERSION="3.13.7" INSTALL_DIR="/opt/python" ADD_LIBSSL="true" && \
sudo apt update && sudo apt install -y build-essential libffi-dev libsqlite3-dev libbz2-dev \
libreadline-dev libncurses5-dev libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev liblzma-dev \
$( [ "$ADD_LIBSSL" = "true" ] && echo "libssl-dev" ) && \
cd /tmp && wget https://www.python.org/ftp/python/$PYTHON_VERSION/Python-$PYTHON_VERSION.tgz && \
tar -xzf Python-$PYTHON_VERSION.tgz && cd Python-$PYTHON_VERSION && \
./configure --enable-optimizations --prefix=$INSTALL_DIR && \
make -j$(nproc) && sudo make altinstall && \
echo "export PATH=$INSTALL_DIR/bin:\$PATH" >> ~/.bashrc && source ~/.bashrc && \
echo "Python $PYTHON_VERSION 已成功安装到 $INSTALL_DIR"
```

## 3. 安装 pip

```bash
# 使用内置模块安装pip
curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
```

## 4. 创建符号链接和配置环境

### 创建符号链接
```bash
ln -sf /usr/local/bin/python3.13 /usr/local/bin/python3
ln -sf /usr/local/bin/python3.13 /usr/local/bin/python
```

### 更新 PATH 环境变量
```bash
echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

## 5. 验证安装

```bash
python --version && python3 --version && python3.13 --version && pip3 --version
which python3.13 && which python3
```

## 6. 安装常用包

```bash
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
