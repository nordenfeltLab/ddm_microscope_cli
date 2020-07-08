import github_api
#import json, streams

proc main() = 
    let 
        token_path = "srvcom_token.txt"
        #git_path = "/repos/nordenfeltLab/comp_srv/releases/latest"
        git_path = "/comp_srv/releases/latest"
        f = open(token_path, fmRead)
    defer: f.close()
    let 
        token = readLine(f)
        client = newGithubApiClient(token)
    var url = client.baseUrl / git_path
    #github_api.request(client, git_path)
    echo url


#let file_destination = "C:/ProgramFiles/NIS-Elements/srvcom.dll"

main()