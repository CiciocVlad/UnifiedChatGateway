import { Socket } from 'phoenix'
import 'phoenix_html'
import { LiveSocket } from 'phoenix_live_view'
import Trix from 'trix'
import '../css/app.css'
import topbar from '../vendor/topbar'

const pica = require('pica')()

let csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute('content')

const MAX_WIDTH_THUMBNAIL = 212

const MAX_WIDTH = 1024
const MAX_HEIGHT = 1024

const BORDER_SIZE = 2
const TYPING_TIMEOUT = 4000

const resizeChatInputBox = (chatInputBox, e) => {
  const currentHeight = parseInt(getComputedStyle(chatInputBox, '').height)
  const dx = m_pos - e.y
  if (currentHeight >= 420 && dx >= 0) return
  if (currentHeight <= 60 && dx <= 0) return
  m_pos = e.y
  chatInputBox.style.height = chatInputBoxHeight = currentHeight + dx + 'px'
}

const resizeChatInputBoxOnPhone = (chatInputBox, e) => {
  const currentHeight = parseInt(getComputedStyle(chatInputBox, '').height)
  const dx = m_pos - e.touches[0].clientY
  if (currentHeight >= 420 && dx >= 0) return
  if (currentHeight <= 60 && dx <= 0) return
  m_pos = e.touches[0].clientY
  chatInputBox.style.height = chatInputBoxHeight = currentHeight + dx + 'px'
}

const processingTheMessageToBeSent = async () => {
  const trix = document.querySelector('trix-editor')
  const parser = new DOMParser()
  const doc = parser.parseFromString(trix.innerHTML, 'text/html')

  // iterate over each child node of the root div element
  if (!doc.querySelector('div'))
    return
  const children = Array.from(doc.querySelector('div').childNodes)
  let dataToSend = []

  for (const index in children) {
    const child = children[index]

    // Skip Trix-specific elements
    if (child.nodeType === Node.ELEMENT_NODE && child.tagName !== 'FIGURE') {
      const attributeNames = child.getAttributeNames()
      const hasTrixAttribute = attributeNames.some(name =>
        /^data-trix-.*/.test(name)
      )
      if (hasTrixAttribute) {
        continue
      }
    }

    // if the child is a figure element, it will be an attachment.
    if (
      child.tagName === 'FIGURE' &&
      child.className.includes('attachment--content')
    ) {
      dataToSend.push({
        format: 'file',
        fileid: child
          .querySelector('.attached-document')
          .getAttribute('phx-value-id'),
        fileName: child.querySelector('.attached-document p').getAttribute('id')
      })
    } else if (
      child.tagName === 'FIGURE' &&
      child.className.includes('attachment--preview')
    ) {
      // it should be an inline image instead of an attachment content
      const imageBlobSrc = child.querySelector('img')?.getAttribute('src')
      const imageWidth = child.querySelector('img')?.getAttribute('width')
      const imageHeight = child.querySelector('img')?.getAttribute('height')
      const base64Src = await blobUrlToBase64(imageBlobSrc)
      dataToSend.push({
        format: 'html',
        content: `<div><img src="${base64Src}" width="${imageWidth}" height="${imageHeight}" style="max-width: 100%; height: auto;"></div>`
      })
    } else {
      let htmlContent = ''
      // filter out last character if it is empty string
      if (
        (index == children.length - 1 || index == 0) &&
        child.textContent.trim() === '\u200b'
      ) {
        continue
      }

      if (child.nodeName === '#text') {
        htmlContent += child.textContent
      } else {
        // in case of the #comment, the child doesn't have outerHTML content, so will skip the empty values
        if (!child.outerHTML) {
          continue
        }

        htmlContent += child.outerHTML
      }

      const lastObject = dataToSend[dataToSend.length - 1]
      if (lastObject?.format === 'html') {
        lastObject.content += htmlContent
      } else {
        const htmlObject = {
          format: 'html',
          content: htmlContent
        }
        dataToSend.push(htmlObject)
      }
    }
  }

  return dataToSend
}

const blobUrlToBase64 = async blobUrl => {
  const response = await fetch(blobUrl)
  const blob = await response.blob()
  const reader = new FileReader()
  reader.readAsDataURL(blob)
  return new Promise((resolve, reject) => {
    reader.onloadend = () => {
      resolve(reader.result)
    }
    reader.onerror = reject
  })
}

// editor area resizing with border line
const editorAreaResizing = () => {
  const chatInputBox = document.getElementById('chat-input-box')
  const messageBox = document.getElementById('message-box')
  const eventFunc = e => resizeChatInputBox(chatInputBox, e)
  const eventFuncPhone = e => resizeChatInputBoxOnPhone(chatInputBox, e)
  chatInputBox.addEventListener(
    'mousedown',
    e => {
      if (e.offsetY < BORDER_SIZE) {
        m_pos = e.y
        document.addEventListener('mousemove', eventFunc, false)
      }
    },
    false
  )
  chatInputBox.addEventListener(
    'touchstart',
    e => {
      messageBox.style.overflowY = 'hidden'
      m_pos = e.touches[0].clientY
      document.addEventListener('touchmove', eventFuncPhone, false)
    },
    false
  )

  document.addEventListener(
    'mouseup',
    () => {
      document.removeEventListener('mousemove', eventFunc, false)
    },
    false
  )

  document.addEventListener(
    'touchend',
    e => {
      messageBox.style.overflowY = 'auto'
      document.removeEventListener('touchmove', eventFuncPhone, false)
    },
    false
  )
}

// resize preview photo form image
const resize = async (img, type, max_width, max_height = 0) => {
  const canvas = document.createElement('canvas')
  if (max_height === 0 || img.width > img.height) {
    canvas.width = max_width < img.width ? max_width : img.width
    canvas.height = (canvas.width * img.height) / img.width
  } else {
    canvas.height = max_height < img.height ? max_height : img.height
    canvas.width = (canvas.height * img.width) / img.height
  }

  const result = await pica.resize(img, canvas)
  const dataurl = result.toDataURL(type, 1.0)

  scaled_down_original = dataurl

  return dataurl
}

let typing = false
let Hooks = {}

Hooks.TakePhoto = {
  mounted() {
    const reader = new FileReader()
    const open_camera = document.getElementById('open-camera')
    open_camera.addEventListener('change', () => {
      let files = document.getElementById('open-camera').files
      reader.onload = async event => {
        const img = new Image()
        img.src = event.target.result
        const hook = this

        img.onload = async function () {
          const thumbnail = await resize(
            this,
            files[0].type,
            MAX_WIDTH_THUMBNAIL
          )
          const scaled_down_original = await resize(
            this,
            files[0].type,
            MAX_WIDTH,
            MAX_HEIGHT
          )
          const size = Math.round(scaled_down_original.length * 0.75)

          hook.pushEvent('change-layout')
          hook.pushEvent(
            'save_image',
            { content: thumbnail, size, navigation: 'photo' },
            ({ messageid }, _ref) =>
              sessionStorage.setItem('messageid', messageid)
          )
          sessionStorage.setItem('thumbnail', thumbnail)
          sessionStorage.setItem('scaled_down_original', scaled_down_original)
          sessionStorage.setItem('size', size)
        }
      }
      reader.readAsDataURL(files[0], 1.0)
    })
  }
}
Hooks.SelectFromGallery = {
  mounted() {
    const reader = new FileReader()
    const open_gallery = document.getElementById('open-gallery')
    open_gallery.addEventListener('change', () => {
      let files = document.getElementById('open-gallery').files
      reader.onload = async event => {
        const img = new Image()
        img.src = event.target.result
        const hook = this

        img.onload = async function () {
          const thumbnail = await resize(
            this,
            files[0].type,
            MAX_WIDTH_THUMBNAIL
          )
          const scaled_down_original = await resize(
            this,
            files[0].type,
            MAX_WIDTH,
            MAX_HEIGHT
          )
          const size = Math.round(scaled_down_original.length * 0.75)

          hook.pushEvent('change-layout')
          hook.pushEvent(
            'save_image',
            { content: thumbnail, size, navigation: 'photo' },
            ({ messageid }, _ref) =>
              sessionStorage.setItem('messageid', messageid)
          )
          sessionStorage.setItem('thumbnail', thumbnail)
          sessionStorage.setItem('scaled_down_original', scaled_down_original)
          sessionStorage.setItem('size', size)
        }
      }
      reader.readAsDataURL(files[0], 1.0)
    })
  }
}
Hooks.PhotoPreview = {
  mounted() {
    const image = sessionStorage.getItem('thumbnail')
    if (image) {
      const preview_image = document.getElementById('preview-image')
      preview_image.setAttribute(
        'src',
        sessionStorage.getItem('scaled_down_original')
      )
      this.pushEvent('change-layout')
      this.pushEvent(
        'restore',
        { content: image, size: sessionStorage.getItem('size') },
        ({ messageid }, _ref) => {
          // if (messageid !== sessionStorage.getItem('messageid'))
          //   sessionStorage.clear()
        }
      )
    }
  },
  updated() {
    const preview_image = document.getElementById('preview-image')
    preview_image.setAttribute('src', scaled_down_original)
  }
}
Hooks.ChatForm = {
  mounted() {
    const submit = document.querySelector(
      '.editor-area .chat-input-box #submit-button'
    )
    const trixEditor = document.querySelector('trix-editor')
    const chatInputBox = document.getElementById('chat-input-box')
    const chatInput = document.getElementById('chat-input')

    editorAreaResizing()
    ;['input', 'paste'].forEach(event =>
      trixEditor.addEventListener(event, () => {
        chatInputBoxHeight = 'auto'
        chatInputBox.style.height = chatInputBoxHeight
      })
    )

    trixEditor.addEventListener('keypress', event => {
      // chat messages should be sent with Enter key
      if (event?.key === 'Enter' && !event?.shiftKey) {
        event.preventDefault()
        submit.click()
      }

      if (!typing) {
        this.pushEvent('sendtyping')
        setTimeout(() => {
          typing = false
        }, TYPING_TIMEOUT)
        typing = true
      }
    })

    submit.addEventListener('click', async e => {
      e.preventDefault()
      this.pushEvent('send_document', {
        input_value: await processingTheMessageToBeSent()
      })
      chatInputBoxHeight = 'auto'
      chatInput.value = ""
      trixEditor.innerHTML = ""
    })
  },
  updated() {
    const chatInputBox = document.getElementById('chat-input-box')
    chatInputBox.style.height = chatInputBoxHeight
  }
}

Hooks.ChatInput = {
  mounted() {
    const emotes = document.getElementById('emotes')
    const emoji = document.getElementById('emoji')
    const emote = document.querySelectorAll('.emote')
    const trixEditor = document.querySelector('trix-editor')
    const smaller = document.getElementById('smaller')
    const larger = document.getElementById('larger')

    smaller.addEventListener('click', event => {
      event.preventDefault()
      let size = parseInt(getComputedStyle(trixEditor).fontSize.split('px')[0])
      if (size > 12) {
        trixEditor.style.fontSize = --size + 'px'
        const p = document.querySelectorAll('p')
        Array.from(p).slice(0, -1).map(x => x.style.fontSize = size + 'px')
        this.pushEvent('change_font_size', { size })
      }
    })

    larger.addEventListener('click', event => {
      event.preventDefault()
      let size = parseInt(getComputedStyle(trixEditor).fontSize.split('px')[0])
      if (size < 20) {
        trixEditor.style.fontSize = ++size + 'px'
        const p = document.querySelectorAll('p')
        Array.from(p).slice(0, -1).map(x => x.style.fontSize = size + 'px')
        this.pushEvent('change_font_size', { size })
      }
    })

    Trix.config.attachments.preview.url = false

    trixEditor.addEventListener('trix-paste', event => {
      const plainText = event.target.value.replace(/<[^>]+>/g, '')
      event.target.editor.undo()
      trixEditor.editor.insertHTML(plainText)
    })

    // Emoji dropdown functionality - START
    emoji.addEventListener('click', () => {
      emotes.style.display =
        !emotes.style.display || emotes.style.display === 'none'
          ? 'flex'
          : 'none'
    })

    emote.forEach(e =>
      e.addEventListener('click', function (event) {
        event.preventDefault()
        trixEditor.editor.insertHTML(this.innerHTML)
        emotes.style.display = 'none'
      })
    )

    window.addEventListener('click', e => {
      if (!emoji.contains(e.target)) {
        emotes.style.display = 'none'
      }
    })

    document.onkeydown = e => {
      e = e || window.event
      if (e.key === 'Escape') {
        emotes.style.display = 'none'
      }
    }
    // Emoji dropdown functionality - END
  }
}

Hooks.MessageList = {
  updated() {
    const messageBox = document.getElementById('message-box')
    messageBox.scrollTop = messageBox.scrollHeight - messageBox.clientHeight
  }
}

Hooks.SelectDocument = {
  mounted() {
    const reader = new FileReader()
    const open_document = document.getElementById('open-document')
    const hook = this
    const chatInputBox = document.getElementById('chat-input-box')
    const trixEditorElement = document.querySelector('trix-editor')

    new ResizeObserver(
      () => (chatInputBox.height = trixEditorElement.offsetHeight)
    ).observe(trixEditorElement)

    open_document.addEventListener('change', function () {
      const size = this.files[0].size
      const name = this.files[0].name
      reader.onload = async event => {
        const file = event.target.result
        hook.pushEvent(
          'save_document',
          { content: file, name, size },
          ({ file_id, embed }, _ref) => {
            if(file_id !== null) {
              const attachment = new Trix.Attachment({ content: embed })
              trixEditorElement.editor.insertAttachment(attachment)
              trixEditorElement.editor.insertHTML(
                '<span class="zws">\u200b</span><br/>'
              )
              documents[file_id] = attachment
            }else{
              console.log("upload error")
            }
          }
        )
      }
      reader.readAsDataURL(this.files[0], 1.0)
    })
  }
}
Hooks.ChatWrapper = {
  mounted() {
    const editorArea = document.querySelector('form.editor-area')
    const header = document.querySelector('.chat-header')
    const messageBox = document.getElementById('message-box')

    if (!editorArea || !header) {
      console.warn('It looks like there is an issue with ChatWrapper hook.')
      return
    }

    let contentInnerHeight =
      parseInt(
        getComputedStyle(messageBox, '').getPropertyValue('min-height')
      ) +
      editorArea?.offsetHeight +
      header?.offsetHeight

    if (window.innerHeight < contentInnerHeight) {
      document.documentElement.style.setProperty(
        '--vh',
        `${
          messageBox?.offsetHeight +
          editorArea?.offsetHeight +
          header?.offsetHeight
        }px`
      )
    } else {
      document.documentElement.style.setProperty(
        '--vh',
        `${window.innerHeight}px`
      )
    }

    window.addEventListener('resize', function () {
      let contentInnerHeight =
        parseInt(
          getComputedStyle(messageBox, '').getPropertyValue('min-height')
        ) +
        editorArea?.offsetHeight +
        header?.offsetHeight

      if (window.innerHeight < contentInnerHeight) {
        document.documentElement.style.setProperty(
          '--vh',
          `${
            messageBox?.offsetHeight +
            editorArea?.offsetHeight +
            header?.offsetHeight
          }px`
        )
      } else {
        document.documentElement.style.setProperty(
          '--vh',
          `${window.innerHeight}px`
        )
      }
    })
  }
}

document.addEventListener('trix-change', () => {
  const trixEditorElement = document.querySelector('trix-editor')
  document.querySelectorAll('.remove').forEach(btn =>
    btn.addEventListener('click', function (event) {
      event.preventDefault()
      trixEditorElement.editorController.removeAttachment(
        documents[this.getAttribute('id')]
      )
      delete documents[this.getAttribute('id')]
    })
  )
})

window.addEventListener('phx:save', params => {
  const { tenant_id, contact_point_id, contact_id, url, file_id } =
    params.detail
  uploadPhoto(
    tenant_id,
    contact_point_id,
    contact_id,
    file_id,
    scaled_down_original,
    url
  )
  sessionStorage.setItem('success', true)
})

window.addEventListener('phx:clear', _params => sessionStorage.clear())

window.addEventListener('phx:file-download', params => {
  const link = document.createElement('a')
  link.download = params.detail.file_name
  link.href = 'data:application/octet-stream;base64,' + params.detail.data
  link.target = '_blank'
  document.body.appendChild(link)
  link.click()
  link.parentNode.removeChild(link)
})

const uploadPhoto = async (
  tenant_id,
  contact_point_id,
  contact_id,
  file_id,
  file,
  url
) => {
  const form = new FormData()
  form.append('file', file)
  const header = {
    method: 'POST',
    body: form
  }
  fetch(
    `${url}/chat/contactpoints/${contact_point_id}/contacts/${contact_id}/tenants/${tenant_id}/chat-contents/${file_id}`,
    header
  )
}

const documents = {}
let scaled_down_original = sessionStorage.getItem('scaled_down_original')
let timezone = Intl.DateTimeFormat().resolvedOptions().timeZone
let liveSocket = new LiveSocket('/chat/live', Socket, {
  params: {
    _csrf_token: csrfToken,
    timezone: timezone
  },
  hooks: Hooks
})
let m_pos
let chatInputBoxHeight

topbar.config({ barColors: { 0: '#29d' }, shadowColor: 'rgba(0, 0, 0, .3)' })
window.addEventListener('phx:page-loading-start', info => topbar.show())
window.addEventListener('phx:page-loading-stop', info => topbar.hide())

liveSocket.connect()

window.liveSocket = liveSocket
