import org.sonatype.nexus.security.realm.RealmManager
import org.sonatype.nexus.repository.attributes.AttributesFacet
import org.sonatype.nexus.security.user.UserManager
import org.sonatype.nexus.repository.manager.RepositoryManager
import org.sonatype.nexus.security.user.UserNotFoundException

/* Use the container to look up some services. */
realmManager = container.lookup(RealmManager.class)
userManager = container.lookup(UserManager.class, "default") //default user manager
repositoryManager = container.lookup(RepositoryManager.class)

/* Managers are used when scripting api cannot. Note that scripting api can only create mostly, and that creation methods return objects of created entities. */
/* Perform cleanup by removing all repos and users. Realms do not need to be re-disabled, admin and anonymous user will not be removed. */
userManager.listUserIds().each({ id ->
    if (id != "anonymous" && id != "admin")
        userManager.deleteUser(id)
})

repositoryManager.browse().each {
    repositoryManager.delete(it.getName())
}

/* Add bearer token realms at the end of realm lists... */
realmManager.enableRealm("NpmToken")
realmManager.enableRealm("DockerToken")

/* Create the docker user. */
security.addUser("docker", "docker", "docker", "docker@example.com", true, "docker", ["nx-anonymous"])

/* Create npm and docker repositories. Their default configuration should be compliant with our requirements, except the docker registry creation. */
repository.createNpmHosted("npm-private")
def r = repository.createDockerHosted("docker", 8082, 0)

/* force basic authentication true by default, must set to false for docker repo. */
conf=r.getConfiguration()
conf.attributes("docker").set("forceBasicAuth", false)
repositoryManager.update(conf)
