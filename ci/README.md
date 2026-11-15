# CI workflows (staged)

`ios-ci.yml` (simulator build + unit tests + UI tests + accessibility audits) and `testflight-upload.yml` (signing and upload, disabled) belong in `.github/workflows/`.

They are staged here because the GitHub login used to create this repository does not have GitHub's `workflow` permission, which GitHub requires for adding files under `.github/workflows/`. To activate CI, move them with a login or agent that has that permission:

    git mv ci/workflows .github/workflows   # keep ci/README.md or delete it
    git commit -m "Enable iOS CI" && git push

The `ios-ci.yml` workflow then runs on every push to main and can also be started from the Actions tab.
