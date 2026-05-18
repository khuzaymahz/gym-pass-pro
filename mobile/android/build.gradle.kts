allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Force every transitive Android module's Kotlin compile to use
// languageVersion / apiVersion 1.8 (the minimum Kotlin 2.x still
// accepts). Several Flutter plugins (sentry_flutter, older
// connectivity_plus / share_plus pins, etc.) still ship Kotlin
// source declared at languageVersion=1.6, which Kotlin 2.2's
// compiler rejects with:
//   "Language version 1.6 is no longer supported; please, use
//    version 1.8 or greater."
// Overriding at the subproject level reaches every plugin module
// without us having to bump each plugin's pubspec pin.
//
// 1.8 is intentional (not 1.9 / 2.0) — it's the floor Kotlin 2.x
// supports, and it doesn't force plugin authors to upgrade
// past sources they actually wrote. Safe lowest-common-denominator.
subprojects {
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            languageVersion.set(org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_1_8)
            apiVersion.set(org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_1_8)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
