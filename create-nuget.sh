#!/bin/bash

# Create a nuget package
# Project name as parameter

main() {
    local name=$1
    local kebabCaseName=$(toKebabCase $name)
    Version="1.0.0"
    Author="Jens\\ Hunt"
    PackageLicenseExpression="LGPLv2.1"
    RepositoryUrl="https://github.com/r0tenur/$kebabCaseName.git"
    RepositoryType="git"
    GenerateDocumentationFile="true"
    PublishRepositoryUrl="true"
    IsPackable="true"
    PackageReadmeFile="README.md"

    # create base folder
    mkdir $(toKebabCase $kebabCaseName)
    cd $kebabCaseName
    
    # Init git
    git init
    
    echo "# $name" > "README.md"
    
    addGitIgnore
    
    dotnet new sln -n "$name"
    
    commit "Setup project"
    
    addSourceProject $name
    
    commit "Add source project"
    
    addTestProject $name
    
    commit "Add test project"
    
    addSampleProject $name
    
    commit "Add sample project"
    
    addPipeline $name
    
    commit "Add pipeline"
    
    echo "Done!"
    echo "Add the following environment variables to your github secrets"
    echo "NUGET_API_KEY"
    echo "CODECOV_TOKEN"
}

addSourceProject() {
    local name=$1
    
    # Create source project
    dotnet new classlib -o "src/$name"
    dotnet sln add "src/$name"

    addInfoPropertyNode "src/$name/$name.csproj" "Version" $Version
    addInfoPropertyNode "src/$name/$name.csproj" "Author" $Author
    addInfoPropertyNode "src/$name/$name.csproj" "PackageLicenseExpression" $PackageLicenseExpression
    addInfoPropertyNode "src/$name/$name.csproj" "RepositoryType" $RepositoryType
    addInfoPropertyNode "src/$name/$name.csproj" "GenerateDocumentationFile" $GenerateDocumentationFile
    addInfoPropertyNode "src/$name/$name.csproj" "PublishRepositoryUrl" $PublishRepositoryUrl
    addInfoPropertyNode "src/$name/$name.csproj" "PackageReadmeFile" $PackageReadmeFile
}

addTestProject() {
    local name=$1
    
    # Create test project
    dotnet new xunit -o "test/$name.Test"
    dotnet sln add "test/$name.Test"
    dotnet add "test/$name.Test" reference "src/$name"
    dotnet add "test/$name.Test" package FakeItEasy
    dotnet add "test/$name.Test" package Shouldly
}
addSampleProject() {
    local name=$1
    
    # Create sample project
    dotnet new console -o "sample/$name.Sample"
    dotnet sln add "sample/$name.Sample"
    dotnet add "sample/$name.Sample" reference "src/$name"
}

toKebabCase () {
    echo $(echo "$(echo $1  | sed -e 's/\([a-z0-9]\)\([A-Z]\)/\1-\2/g' -e 's/\./-/')" | tr '[:upper:]' '[:lower:]')
}

addGitIgnore() {
    local gitignore="
    *.swp
    *.*~
    project.lock.json
    .DS_Store
    *.pyc
    nupkg/
    
    # Rider
    .idea
    
    # User-specific files
    *.suo
    *.user
    *.userosscache
    *.sln.docstates
    
    # Build results
    [Dd]ebug/
    [Dd]ebugPublic/
    [Rr]elease/
    [Rr]eleases/
    x64/
    x86/
    build/
    bld/
    [Bb]in/
    [Oo]bj/
    [Oo]ut/
    msbuild.log
    msbuild.err
    msbuild.wrn
    
    # Visual Studio 2015
    .vs/
    */**/bin
    **/obj"
    echo "$gitignore" > .gitignore
    emptyLine
    echo ".gitignore added"
}

addPipeline() {
    local dotnetVersion=$(dotnet --version)
    local name=$1
    local pipeline="name: CI/CD
    
    on:
    push:
    branches: [ '*' ]
    pull_request:
    branches: [ '*' ]
    create:
    tags:
    - v*
    jobs:
    build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    - name: Setup .NET
    uses: actions/setup-dotnet@v1
    with:
    dotnet-version: $dotnetVersion
    - name: Restore dependencies
    run: dotnet restore
    - name: Build
    run: dotnet build --no-restore
    - name: Test
    run: dotnet test --no-build --collect:\"XPlat Code Coverage\"
    - name: Pack
    run: dotnet pack ./src/$name/$name.csproj -c release -o ./dist
    - name: Publish code coverage
    uses: codecov/codecov-action@v1
    with:
    token: \${{ secrets.CODECOV_TOKEN }}
    file: \"**/coverage.cobertura.xml\"
    flags: unittests
    name: codecov-umbrella
    fail_ci_if_error: true
    verbose: true
    - name: Create Release
    if: startsWith(github.ref, 'refs/tags/v')
    id: create_release
    uses: actions/create-release@v1.0.0
    env:
    GITHUB_TOKEN: \${{ secrets.GITHUB_TOKEN }}
    with:
    tag_name: \${{ github.ref }}
    release_name: Release \${{ github.ref }}
    draft: false
    prerelease: false
    - name: Push to nuget
    if: startsWith(github.ref, 'refs/tags/v')
    env:
    NUGET_API_KEY: \${{ secrets.NugetApiKey }}
    run: cd dist && dotnet nuget push \"*.nupkg\" --api-key \"\$NUGET_API_KEY\" --skip-duplicate --source https://www.nuget.org/api/v2/package"
    mkdir -p .github/workflows
    echo "$pipeline" > .github/workflows/ci-cd.yml
    emptyLine
    echo "Pipeline added"
}

emptyLine() {
    echo ""
}

commit() {
    local message=$1
    git add .
    git commit -m "chore: $message"
}

addInfoPropertyNode () {
    local file=$1
    local name=$2
    local value=$3
    sed -i '' "s/<\/PropertyGroup>/\\ \\ <$name>$value<\/$name> \\ <\/PropertyGroup>/g" "$file"
}

main "$1";
