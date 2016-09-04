fscr=$1
version=$2

summaVersion='character(len=64), parameter     :: summaVersion = '"'"$version"'"
    sed -i "s|character(len=64), parameter     :: summaVersion.*|$summaVersion|" $fscr

   gitBranch='character(len=64), parameter     :: gitBranch = '"'"`git describe --long --dirty --all --always | sed -e's/heads\///'`"'"
    sed -i "s|character(len=64), parameter     :: gitBranch.*|$gitBranch|" $fscr

     gitHash='character(len=64), parameter     :: gitHash = '"'"`git rev-parse HEAD`"'"
    sed -i "s|character(len=64), parameter     :: gitHash.*|$gitHash|" $fscr

   buildTime='character(len=64), parameter     :: buildTime = '"'"`date`"'"
    sed -i "s|character(len=64), parameter     :: buildTime.*|$buildTime|" $fscr
