import { exec } from 'child_process'
import fs from 'fs'
import { promisify } from 'util'

const execAsync = promisify(exec)
const readFileAsync = promisify(fs.readFile)
const writeFileAsync = promisify(fs.writeFile)

async function getLatestVersion(packageName) {
  try {
    const { stdout } = await execAsync(`npm view ${packageName} version`)
    return stdout.trim()
  } catch (error) {
    console.error(`无法获取包 ${packageName} 的版本信息: ${error.message}`)
    process.exit(1)
  }
}

async function processDependencies(dependencies) {
  const result = {}

  for (const [pkg, currentVersion] of Object.entries(dependencies)) {
    if (currentVersion && currentVersion !== '') {
      result[pkg] = currentVersion
      console.log(`✓ ${pkg}: ${currentVersion} (skip)`)
      continue
    }

    const version = await getLatestVersion(pkg)
    result[pkg] = `^${version}`
    console.log(`✓ ${pkg}: ^${version}`)
  }

  return result
}

async function main() {
  try {
    const packageJsonContent = await readFileAsync('package.json', 'utf8')
    const packageJson = JSON.parse(packageJsonContent)

    console.log('正在获取依赖的最新版本...')

    if (packageJson.dependencies) {
      packageJson.dependencies = await processDependencies(packageJson.dependencies)
    }
    if (packageJson.devDependencies) {
      packageJson.devDependencies = await processDependencies(packageJson.devDependencies)
    }

    await writeFileAsync('package.json', JSON.stringify(packageJson, null, 2))
    console.log('\npackage.json 已更新')

    console.log('按任意键退出...')
    process.stdin.setRawMode(true)
    process.stdin.resume()
    process.stdin.on('data', process.exit.bind(process, 0))
  } catch (error) {
    console.error('发生错误:', error)
    process.exit(1)
  }
}

main()
