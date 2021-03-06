#!/bin/bash

# validate that CONFIG_ROOT is defined
if [[ -z $CONFIG_ROOT ]]; then
    echo "Please set 'CONFIG_ROOT' to the configs.git checkout"
    exit 1
fi

# ------------------------------
# Constants and convenience variables

# sub-directories that go under the $HOME directory
HOME_VIM_DIR=$HOME/.vim

VIM_AUTOLOAD_DIR=$HOME_VIM_DIR/autoload
VIM_BUNDLE_DIR=$HOME_VIM_DIR/bundle
VIM_COLOR_DIR=$HOME_VIM_DIR/colors

VIM_VIEW_DIR=$HOME_VIM_DIR/view;
VIM_SWAP_DIR=$HOME_VIM_DIR/swap;

# sub-directories that are rooted under the config.git repository root
PLUGIN_REPO_LIST=$CONFIG_ROOT/vim/plugin_list
COLOR_REPO_LIST=$CONFIG_ROOT/vim/color_list

PATHOGEN_LOAD_DIR=$CONFIG_ROOT/vim/plugins/vim-pathogen/autoload
PLUGIN_DIR=$CONFIG_ROOT/vim/plugins
COLOR_DIR=$CONFIG_ROOT/vim/colors

function prepare_dir {
    dir_path=$1

    echo "checking if directory $dir_path exists..."

    if [[ ! -d $dir_path ]]; then
        mkdir -p $dir_path
    fi
}

function link_dir {
    from_dir=$1
    to_dir=$2

    if [[ ! -e "$from_dir" ]]; then
        echo "linking file $from_dir -> $to_dir"
        ln -s "$to_dir" "$from_dir"
    else
        echo "file $from_dir exists"
    fi
}

function name_from_repo_uri {
    repo_uri=$1

    # regex to extract "/<repository-name>.git" from the end of a repository URI
    repo_name_regex='.*\/\([a-zA-Z0-9_.-]*\)[.]git'

    echo `expr "$repo_uri" : $repo_name_regex`
}

function pull_plugins {
    repo_list_file=$1
    plugin_dir=$2

    while read vim_plugin_entry; do
	# reduce many whitespace to 1, and then use cut.
        vim_plugin_path="$(cut -f1 -d' ' <<<"$(echo $vim_plugin_entry | sed 's/ \+/ /g')")"
        vim_plugin_repo="$(cut -f2 -d' ' <<<"$(echo $vim_plugin_entry | sed 's/ \+/ /g')")"

        plugin_name=$(name_from_repo_uri $vim_plugin_repo)

        echo "checking for plugin '$plugin_dir/$plugin_name'..."

        if [[ -z $plugin_name ]]; then
            echo "unable to extract plugin name from uri: '$vim_plugin_repo'"
        else
            if [[ ! -d "$plugin_dir/$plugin_name" ]]; then
                set -x
                git -C $plugin_dir clone $vim_plugin_repo $vim_plugin_path

                set +x
            else
                echo "plugin $plugin_name already exists..."
            fi
        fi

    done < $repo_list_file
}

function setup_vim {
    # ------------------------------
    # create various directories if necessary

    # base vim directories (typically in $HOME)
    prepare_dir  $HOME_VIM_DIR 
    prepare_dir  $VIM_VIEW_DIR 
    prepare_dir  $VIM_SWAP_DIR 

    # target directories to clone vim plugins and vim colors into
    prepare_dir  $PLUGIN_DIR
    prepare_dir  $COLOR_DIR

    # ------------------------------
    # clone repos for vim plugins and vim colors
    pull_plugins $PLUGIN_REPO_LIST $PLUGIN_DIR
    pull_plugins $COLOR_REPO_LIST  $COLOR_DIR

    # ------------------------------
    # color files need to be in the root color directory. Here we create hardlinks
    for color_file in $(find $COLOR_DIR -name '*.vim' -type f); do
        # name of hardlink to color file definition
        color_file_name=$(basename "$color_file")
        ln "$color_file" "$COLOR_DIR/$color_file_name"
    done

    # ------------------------------
    # setup symlinks (typically from $HOME) and for pathogen plugin
    link_dir     $VIM_BUNDLE_DIR   $PLUGIN_DIR
    link_dir     $VIM_COLOR_DIR    $COLOR_DIR
    link_dir     $VIM_AUTOLOAD_DIR $PATHOGEN_LOAD_DIR
}

function cleanup_vim {
    # cleanup symlinks from $HOME to vim plugins and vim colors
    rm $VIM_BUNDLE_DIR
    rm $VIM_COLOR_DIR

    # cleanup cloned repos for vim plugins and vim colors
    rm -rf "$PLUGIN_DIR"
    rm -rf "$COLOR_DIR"
}


# ------------------------------
# Main

if [[ ! -f ${HOME}/.vimrc ]]; then
   ln -s ${CONFIG_ROOT}/vim/vimrc ${HOME}/.vimrc
else
   echo "vimrc symlink already created. Skipping..."
fi

if [[ ! -d ${HOME}/.vim ]]; then
    echo "<TODO>"
fi

install_cmd=$1

if [[ -z $install_cmd ]]; then
    echo "Usage: [bash] install-vim-plugins.bash <setup | cleanup>"
    exit 1
fi

# run cleanup_vim or setup_vim depending on the command ("setup" or "cleanup", respectively)
[[ $install_cmd = "cleanup" ]] && cleanup_vim
[[ $install_cmd = "setup" ]]   && setup_vim

if [[ $install_cmd != "cleanup" && $install_cmd != "setup" ]]; then
   echo "unknown command $install_cmd"
fi

