# Authentication

<script setup>
import { useData } from 'vitepress'
import { computed } from 'vue'

const { isDark } = useData()
const src = computed(() => isDark.value ? '/screenshots/authentication-dark.png' : '/screenshots/authentication-light.png')
</script>

When first initialized, the default username and password for NestMTX is `nestmtx`. Once you have logged in for the first time, you can change the password and modify accounts under the user management section.

<img :src="src" />

:::info Tip
You will be able to change the password via the [User Management](/setup/users) interface.
:::
