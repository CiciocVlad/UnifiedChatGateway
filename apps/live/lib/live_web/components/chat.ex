defmodule LiveWeb.Components.Chat do
  use LiveWeb, :live_component

  import Phoenix.HTML

  @impl true
  @spec render(any) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id="chat-wrapper" class="chat-wrapper" phx-hook="ChatWrapper">
      <nav class="chat-header" style={"height: #{@configuration |> Map.get("header") |> Map.get("height")}; background-color: #{@configuration |> Map.get("header") |> Map.get("fill")}"}>
        <div class="chat-header-left">
          <img src={Routes.static_path(@socket, "/svg/contact-point-icon.svg")} />
          <h3 class="chat-header-text" style={"justify-content: #{@configuration |> Map.get("header") |> Map.get("align") |> Map.get("horizontal")}; color: #{@configuration |> Map.get("header") |> Map.get("fontColour")}; font-family: #{@configuration |> Map.get("header") |> Map.get("fontFamily")}; font-size: #{@configuration |> Map.get("header") |> Map.get("fontSize")}"}><%= @configuration |> Map.get("header") |> Map.get("label") %></h3>
        </div>
        <div class="chat-header-right">
          <img src={Routes.static_path(@socket, "/svg/minimize.svg")} />
          <img src={Routes.static_path(@socket, "/svg/options.svg")} />
          <img src={Routes.static_path(@socket, "/svg/close.svg")} />
        </div>
      </nav>
      <div id="message-box" class="message-box" style={"background-color: #{@configuration |> Map.get("transcript") |> Map.get("fill")}"}>
        <ul id="msg-list" style="list-style: none" phx-update="append" phx-hook="MessageList">
          <%= for message <- @messages |> Enum.with_index |> Enum.map(fn value -> @messages |> show_bubble(@socket, value, @messages |> length, @configuration) end) |> Enum.reverse do %>
            <%= message |> elem(1) |> raw %>
          <% end %>
        </ul>
        <div class="typing-indicator" style={"display: #{if @typing do "flex" else "none" end}"}>
            <span></span>
            <span></span>
            <span></span>
        </div>
      </div>
      <form id="form" class="editor-area" phx-submit="send_document" phx-update="ignore" phx-hook="ChatForm">
        <div id="chat-input-box" class="chat-input-box" style={"background-color: #{@configuration |> Map.get("input") |> Map.get("fill")}"}>
          <%!-- <textarea
            id="chat-input"
            placeholder="Type your message and press enter..."
            value={@input_value}
            name="input_value"
            style={"resize: none; background-color: #{@configuration |> Map.get("input") |> Map.get("fill")}; color: #{@configuration |> Map.get("input") |> Map.get("fontColour")}"}
            phx-hook="ChatInput"
          /> --%>
          <input id="chat-input" type="hidden" name="content" name="input_value" phx-hook="ChatInput"/>
          <trix-editor input="chat-input" placeholder="Type your message and press enter..." class="trix-content" contenteditable></trix-editor>
          <button id="submit-button" type="submit" style={"background-color: #{@configuration |> Map.get("button") |> Map.get("fill")}"}><svg version="1.2" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" overflow="visible" preserveAspectRatio="none" viewBox="0 0 24 24" width="22" height="22"><g><path xmlns:default="http://www.w3.org/2000/svg" id="paper-plane" d="M21.01,2.82c-0.11-0.07-0.24-0.11-0.37-0.11c-0.12,0-0.23,0.03-0.33,0.09l-17.3,9.99  c-0.32,0.18-0.43,0.58-0.25,0.9c0.07,0.13,0.19,0.24,0.33,0.29l4.12,1.68l11.13-9.63l-9,11v3.63c0,0.28,0.18,0.52,0.44,0.62  c0.08,0.02,0.15,0.02,0.23,0c0.2,0.01,0.39-0.08,0.51-0.24l2.49-3.01l4.72,1.93c0.09,0.04,0.18,0.07,0.28,0.07  c0.11,0,0.22-0.03,0.32-0.08c0.18-0.1,0.3-0.27,0.33-0.47l2.67-16C21.36,3.21,21.24,2.95,21.01,2.82L21.01,2.82z" style={"fill: #{@configuration |> Map.get("button") |> Map.get("iconColour")};"} vector-effect="non-scaling-stroke"/></g></svg></button>
        </div>
        <div class="footer">
          <div class="emoji">
            <div id="emotes" class="emotes">
              <button class="emote">👍</button>
              <button class="emote">👎</button>
              <button class="emote">❤️</button>
              <button class="emote">⭐</button>
              <button class="emote">😀</button>
              <button class="emote">🤔</button>
              <button class="emote">🙂</button>
              <button class="emote">🙁</button>
              <button class="emote">😐</button>
              <button class="emote">😫</button>
            </div>
            <svg id="emoji" version="1.2" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" overflow="visible" preserveAspectRatio="none" viewBox="0 0 16.000389893951745 16.00038989395174" width="16.000389893951745" height="16.00038989395174"><g transform="translate(0, 0)"><g transform="translate(-0.000002540363005962638, 0.0000024343147492916772) rotate(0)"><path style={"stroke-width: 0; stroke-linecap: butt; stroke-linejoin: miter; fill: #{@configuration |> Map.get("input") |> Map.get("iconColour")};"} d="M11.8102,9.86019c0.07,-0.16 0.07,-0.34 0,-0.5c-0.08,-0.18 -0.24,-0.31 -0.43,-0.36c-0.16,-0.07 -0.35,-0.07 -0.51,0c-0.16,0.08 -0.28,0.23 -0.33,0.4c-0.45,1.41 -1.95,2.18 -3.35,1.74c-0.28,-0.09 -0.54,-0.22 -0.77,-0.39c-0.47,-0.33 -0.83,-0.8 -1,-1.35c-0.07,-0.36 -0.42,-0.6 -0.79,-0.53c-0.36,0.07 -0.6,0.42 -0.53,0.79c0.01,0.05 0.02,0.1 0.05,0.14c0.25,0.81 0.75,1.51 1.44,2c1.41,1.04 3.34,1.04 4.75,0c0.69,-0.49 1.19,-1.19 1.44,-2v0zM6.2802,4.39019c-0.5,-0.54 -1.34,-0.56 -1.88,-0.06c-0.54,0.5 -0.56,1.34 -0.06,1.88c0.02,0.02 0.04,0.04 0.06,0.06c0.5,0.54 1.34,0.56 1.88,0.06c0.54,-0.5 0.56,-1.34 0.06,-1.88c-0.02,-0.02 -0.04,-0.04 -0.06,-0.06zM11.6102,4.39019c-0.5,-0.54 -1.34,-0.56 -1.88,-0.06c-0.54,0.5 -0.56,1.34 -0.06,1.88c0.02,0.02 0.04,0.04 0.06,0.06c0.5,0.54 1.34,0.56 1.88,0.06c0.54,-0.5 0.56,-1.34 0.06,-1.88c-0.02,-0.02 -0.04,-0.04 -0.06,-0.06zM14.1302,10.58019c-0.67,1.61 -1.94,2.88 -3.55,3.55c-1.65,0.71 -3.52,0.71 -5.17,0c-1.61,-0.67 -2.88,-1.94 -3.55,-3.55c-0.71,-1.65 -0.71,-3.52 0,-5.17c0.67,-1.6 1.95,-2.88 3.55,-3.54c1.65,-0.71 3.52,-0.71 5.17,0c1.61,0.67 2.88,1.94 3.55,3.55c0.71,1.65 0.71,3.52 0,5.17zM14.9202,4.00019c-0.7,-1.21 -1.71,-2.22 -2.92,-2.92c-1.21,-0.71 -2.59,-1.09 -4,-1.08c-1.41,-0.01 -2.79,0.37 -4,1.08c-1.21,0.7 -2.22,1.71 -2.92,2.92c-0.71,1.21 -1.09,2.59 -1.08,4c-0.01,1.41 0.36,2.79 1.07,4c0.7,1.21 1.71,2.22 2.93,2.92c1.21,0.71 2.59,1.09 4,1.08c1.41,0.01 2.79,-0.36 4,-1.07c1.21,-0.7 2.22,-1.71 2.92,-2.93c0.71,-1.21 1.09,-2.59 1.08,-4c0.01,-1.41 -0.37,-2.79 -1.08,-4z" vector-effect="non-scaling-stroke"/></g><defs><path id="path-1678878262179859" d="M11.8102,9.86019c0.07,-0.16 0.07,-0.34 0,-0.5c-0.08,-0.18 -0.24,-0.31 -0.43,-0.36c-0.16,-0.07 -0.35,-0.07 -0.51,0c-0.16,0.08 -0.28,0.23 -0.33,0.4c-0.45,1.41 -1.95,2.18 -3.35,1.74c-0.28,-0.09 -0.54,-0.22 -0.77,-0.39c-0.47,-0.33 -0.83,-0.8 -1,-1.35c-0.07,-0.36 -0.42,-0.6 -0.79,-0.53c-0.36,0.07 -0.6,0.42 -0.53,0.79c0.01,0.05 0.02,0.1 0.05,0.14c0.25,0.81 0.75,1.51 1.44,2c1.41,1.04 3.34,1.04 4.75,0c0.69,-0.49 1.19,-1.19 1.44,-2v0zM6.2802,4.39019c-0.5,-0.54 -1.34,-0.56 -1.88,-0.06c-0.54,0.5 -0.56,1.34 -0.06,1.88c0.02,0.02 0.04,0.04 0.06,0.06c0.5,0.54 1.34,0.56 1.88,0.06c0.54,-0.5 0.56,-1.34 0.06,-1.88c-0.02,-0.02 -0.04,-0.04 -0.06,-0.06zM11.6102,4.39019c-0.5,-0.54 -1.34,-0.56 -1.88,-0.06c-0.54,0.5 -0.56,1.34 -0.06,1.88c0.02,0.02 0.04,0.04 0.06,0.06c0.5,0.54 1.34,0.56 1.88,0.06c0.54,-0.5 0.56,-1.34 0.06,-1.88c-0.02,-0.02 -0.04,-0.04 -0.06,-0.06zM14.1302,10.58019c-0.67,1.61 -1.94,2.88 -3.55,3.55c-1.65,0.71 -3.52,0.71 -5.17,0c-1.61,-0.67 -2.88,-1.94 -3.55,-3.55c-0.71,-1.65 -0.71,-3.52 0,-5.17c0.67,-1.6 1.95,-2.88 3.55,-3.54c1.65,-0.71 3.52,-0.71 5.17,0c1.61,0.67 2.88,1.94 3.55,3.55c0.71,1.65 0.71,3.52 0,5.17zM14.9202,4.00019c-0.7,-1.21 -1.71,-2.22 -2.92,-2.92c-1.21,-0.71 -2.59,-1.09 -4,-1.08c-1.41,-0.01 -2.79,0.37 -4,1.08c-1.21,0.7 -2.22,1.71 -2.92,2.92c-0.71,1.21 -1.09,2.59 -1.08,4c-0.01,1.41 0.36,2.79 1.07,4c0.7,1.21 1.71,2.22 2.93,2.92c1.21,0.71 2.59,1.09 4,1.08c1.41,0.01 2.79,-0.36 4,-1.07c1.21,-0.7 2.22,-1.71 2.92,-2.93c0.71,-1.21 1.09,-2.59 1.08,-4c0.01,-1.41 -0.37,-2.79 -1.08,-4z" vector-effect="non-scaling-stroke"/></defs></g></svg>
            <label class="select-document">
              <input id="open-document" type="file" accept="pdf" phx-hook="SelectDocument" style="display: none" />
              <svg version="1.2" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" overflow="visible" preserveAspectRatio="none" viewBox="0 0 14.600685119628906 15.910957336425781" width="14.600685119628906" height="15.910957336425781"><g transform="translate(0, 0)"><defs><path id="path-1678878262178857" d="M19.280002647034028 17.129999533899106 C19.300002649779913 16.209999558931962 18.940002600353967 15.31999958314853 18.28000250973973 14.679999600562692 C18.28000250973973 14.679999600562692 12.280001685973955 8.679999763820447 12.280001685973955 8.679999763820447 C11.880001631056237 8.249999775520587 11.32000155417143 8.009999782050896 10.730001473167796 8.0199997817788 C9.630001322144071 8.0199997817788 8.730001198579204 8.919999757290137 8.730001198579204 10.019999727359549 C8.720001197206262 10.60999971130587 8.960001230156893 11.169999696068478 9.390001289193439 11.569999685184628 C9.390001289193439 11.569999685184628 13.660001875440082 15.839999568999525 13.660001875440082 15.839999568999525 C13.72000188367774 15.89999956736695 13.800001894661285 15.939999566278562 13.890001907017771 15.939999566278562 C14.080001933103686 15.889999567639043 14.26000195781666 15.779999570632103 14.380001974291977 15.619999574985643 C14.540001996259063 15.499999578250799 14.650002011361435 15.31999958314853 14.70000201822615 15.12999958831836 C14.70000201822615 15.039999590767225 14.660002012734381 14.959999592943996 14.600002004496723 14.899999594576572 C14.600002004496723 14.899999594576572 10.190001399028876 10.629999710761675 10.190001399028876 10.629999710761675 C10.03000137706179 10.469999715115216 9.940001364705303 10.259999720829239 9.93000136333236 10.039999726815354 C9.920001361959418 9.659999737155012 10.210001401774763 9.349999745589997 10.590001453946595 9.339999745862094 C10.60000145531954 9.339999745862094 10.620001458065424 9.339999745862094 10.630001459438366 9.339999745862094 C10.860001491016055 9.339999745862094 11.0800015212208 9.429999743413228 11.25000154456083 9.589999739059687 C11.25000154456083 9.589999739059687 17.250002368326605 15.589999575801933 17.250002368326605 15.589999575801933 C17.710002431481982 15.969999565462276 17.98000246855144 16.529999550224886 17.99000246992438 17.129999533899106 C18.01000247267027 17.959999511315118 17.360002383428977 18.649999492540477 16.53000226947471 18.669999491996283 C16.500002265355878 18.669999491996283 16.480002262609993 18.669999491996283 16.450002258491168 18.669999491996283 C15.870002178860476 18.67999949172419 15.31000210197567 18.459999497710303 14.910002047057953 18.039999509138347 C14.910002047057953 18.039999509138347 6.830000937720041 9.929999729808415 6.830000937720041 9.929999729808415 C6.300000864954064 9.449999742869034 5.990000822392833 8.759999761643677 5.990000822392833 8.039999781234608 C5.990000822392833 7.329999800553441 6.280000862208179 6.649999819055988 6.79000093222827 6.159999832388704 C7.270000998129531 5.649999846265613 7.950001091489653 5.369999853884308 8.65000118759566 5.379999853612212 C9.36000128507461 5.379999853612212 10.040001378434733 5.669999845721421 10.530001445708937 6.179999831844511 C10.530001445708937 6.179999831844511 16.840002312035942 12.499999659879677 16.840002312035942 12.499999659879677 C16.9000023202736 12.559999658247099 16.990002332630088 12.599999657158714 17.08000234498657 12.599999657158714 C17.27000237107249 12.549999658519194 17.44000239441252 12.439999661512253 17.560002410887837 12.279999665865793 C17.720002432854923 12.159999669130949 17.830002447957295 11.989999673756586 17.88000245482201 11.799999678926413 C17.88000245482201 11.70999968137528 17.84000244933024 11.62999968355205 17.78000244109258 11.569999685184627 C17.78000244109258 11.569999685184627 11.490001577511459 5.259999856877367 11.490001577511459 5.259999856877367 C10.75000147591368 4.479999878100875 9.720001334500555 4.03999989007311 8.650001187595658 4.03999989007311 C7.5900010420637045 4.0299998903452074 6.570000902023523 4.469999878372971 5.85000080317163 5.23999985742156 C5.1000007002009085 5.979999837286438 4.680000642537305 6.989999809804715 4.7000006452831915 8.039999781234608 C4.690000643910248 9.099999752392405 5.120000702946795 10.119999724638586 5.88000080729046 10.859999704503462 C5.88000080729046 10.859999704503462 13.990001920747199 18.94999948437759 13.990001920747199 18.94999948437759 C14.630002008615548 19.609999466419236 15.520002130807471 19.96999945662377 16.440002257118223 19.949999457167962 C17.99000246992438 19.979999456351674 19.27000264566108 18.73999949009161 19.30000264977991 17.18999953226653 C19.30000264977991 17.159999533082818 19.30000264977991 17.119999534171203 19.30000264977991 17.08999953498749 C19.30000264977991 17.08999953498749 19.30000264977991 17.08999953498749 19.30000264977991 17.08999953498749 C19.30000264977991 17.08999953498749 19.280002647034028 17.129999533899106 19.280002647034028 17.129999533899106 Z" vector-effect="non-scaling-stroke"></path></defs><g transform="translate(-4.699317530151003, -4.039833058435044)"><path style="stroke-width: 0; stroke-linecap: butt; stroke-linejoin: miter; fill: #a7a7a7; display: block" d="M19.280002647034028 17.129999533899106 C19.300002649779913 16.209999558931962 18.940002600353967 15.31999958314853 18.28000250973973 14.679999600562692 C18.28000250973973 14.679999600562692 12.280001685973955 8.679999763820447 12.280001685973955 8.679999763820447 C11.880001631056237 8.249999775520587 11.32000155417143 8.009999782050896 10.730001473167796 8.0199997817788 C9.630001322144071 8.0199997817788 8.730001198579204 8.919999757290137 8.730001198579204 10.019999727359549 C8.720001197206262 10.60999971130587 8.960001230156893 11.169999696068478 9.390001289193439 11.569999685184628 C9.390001289193439 11.569999685184628 13.660001875440082 15.839999568999525 13.660001875440082 15.839999568999525 C13.72000188367774 15.89999956736695 13.800001894661285 15.939999566278562 13.890001907017771 15.939999566278562 C14.080001933103686 15.889999567639043 14.26000195781666 15.779999570632103 14.380001974291977 15.619999574985643 C14.540001996259063 15.499999578250799 14.650002011361435 15.31999958314853 14.70000201822615 15.12999958831836 C14.70000201822615 15.039999590767225 14.660002012734381 14.959999592943996 14.600002004496723 14.899999594576572 C14.600002004496723 14.899999594576572 10.190001399028876 10.629999710761675 10.190001399028876 10.629999710761675 C10.03000137706179 10.469999715115216 9.940001364705303 10.259999720829239 9.93000136333236 10.039999726815354 C9.920001361959418 9.659999737155012 10.210001401774763 9.349999745589997 10.590001453946595 9.339999745862094 C10.60000145531954 9.339999745862094 10.620001458065424 9.339999745862094 10.630001459438366 9.339999745862094 C10.860001491016055 9.339999745862094 11.0800015212208 9.429999743413228 11.25000154456083 9.589999739059687 C11.25000154456083 9.589999739059687 17.250002368326605 15.589999575801933 17.250002368326605 15.589999575801933 C17.710002431481982 15.969999565462276 17.98000246855144 16.529999550224886 17.99000246992438 17.129999533899106 C18.01000247267027 17.959999511315118 17.360002383428977 18.649999492540477 16.53000226947471 18.669999491996283 C16.500002265355878 18.669999491996283 16.480002262609993 18.669999491996283 16.450002258491168 18.669999491996283 C15.870002178860476 18.67999949172419 15.31000210197567 18.459999497710303 14.910002047057953 18.039999509138347 C14.910002047057953 18.039999509138347 6.830000937720041 9.929999729808415 6.830000937720041 9.929999729808415 C6.300000864954064 9.449999742869034 5.990000822392833 8.759999761643677 5.990000822392833 8.039999781234608 C5.990000822392833 7.329999800553441 6.280000862208179 6.649999819055988 6.79000093222827 6.159999832388704 C7.270000998129531 5.649999846265613 7.950001091489653 5.369999853884308 8.65000118759566 5.379999853612212 C9.36000128507461 5.379999853612212 10.040001378434733 5.669999845721421 10.530001445708937 6.179999831844511 C10.530001445708937 6.179999831844511 16.840002312035942 12.499999659879677 16.840002312035942 12.499999659879677 C16.9000023202736 12.559999658247099 16.990002332630088 12.599999657158714 17.08000234498657 12.599999657158714 C17.27000237107249 12.549999658519194 17.44000239441252 12.439999661512253 17.560002410887837 12.279999665865793 C17.720002432854923 12.159999669130949 17.830002447957295 11.989999673756586 17.88000245482201 11.799999678926413 C17.88000245482201 11.70999968137528 17.84000244933024 11.62999968355205 17.78000244109258 11.569999685184627 C17.78000244109258 11.569999685184627 11.490001577511459 5.259999856877367 11.490001577511459 5.259999856877367 C10.75000147591368 4.479999878100875 9.720001334500555 4.03999989007311 8.650001187595658 4.03999989007311 C7.5900010420637045 4.0299998903452074 6.570000902023523 4.469999878372971 5.85000080317163 5.23999985742156 C5.1000007002009085 5.979999837286438 4.680000642537305 6.989999809804715 4.7000006452831915 8.039999781234608 C4.690000643910248 9.099999752392405 5.120000702946795 10.119999724638586 5.88000080729046 10.859999704503462 C5.88000080729046 10.859999704503462 13.990001920747199 18.94999948437759 13.990001920747199 18.94999948437759 C14.630002008615548 19.609999466419236 15.520002130807471 19.96999945662377 16.440002257118223 19.949999457167962 C17.99000246992438 19.979999456351674 19.27000264566108 18.73999949009161 19.30000264977991 17.18999953226653 C19.30000264977991 17.159999533082818 19.30000264977991 17.119999534171203 19.30000264977991 17.08999953498749 C19.30000264977991 17.08999953498749 19.30000264977991 17.08999953498749 19.30000264977991 17.08999953498749 C19.30000264977991 17.08999953498749 19.280002647034028 17.129999533899106 19.280002647034028 17.129999533899106 Z" vector-effect="non-scaling-stroke"></path></g></g></svg>
            </label>
          </div>
          <p style={"display: #{if @configuration |> Map.get("permissions") |> Map.get("displayFooter") do "block" else "none" end}"}>Powered by Premier Contact Point</p>
          <div class="edit-text-size">
            <button id="smaller"><svg height="14" overflow="visible" viewBox="0 0 12 14" width="12" xmlns="http://www.w3.org/2000/svg"><g><defs><path id="path-168354974462720" d="M11.887487798679004 1.5261841283117756 C11.692610949520333 1.322692911203539 11.400295675782324 1.2209473026494206 11.205418826623651 1.322692911203539 C11.205418826623651 1.322692911203539 9.938719307092281 2.136657779636486 9.938719307092281 2.136657779636486 C9.938719307092281 2.136657779636486 8.769458212140249 1.322692911203539 8.769458212140249 1.322692911203539 C8.47714293840224 1.2209473026494206 8.184827664664233 1.2209473026494206 8.087389240084898 1.5261841283117756 C7.892512390926224 1.7296753454200124 7.989950815505559 2.0349121710823677 8.184827664664233 2.2384033881906045 C8.184827664664233 2.2384033881906045 9.74384245793361 3.2558594737317885 9.74384245793361 3.2558594737317885 C9.841280882512946 3.357605082285907 9.938719307092281 3.357605082285907 10.036157731671619 3.357605082285907 C10.133596156250954 3.357605082285907 10.231034580830292 3.357605082285907 10.328473005409629 3.2558594737317885 C10.328473005409629 3.2558594737317885 11.887487798679006 2.2384033881906045 11.887487798679006 2.2384033881906045 C11.984926223258341 2.0349121710823677 12.082364647837677 1.7296753454200124 11.887487798679004 1.5261841283117756 Z" vector-effect="non-scaling-stroke"/></defs> <path style="stroke-width: 0; stroke-linecap: butt; stroke-linejoin: miter; fill: rgb(167, 167, 167);" d="M11.887487798679444 0.2643428451941645 C11.692610949520827 0.060851628085856646 11.400295675782786 -0.04089398046824044 11.205418826624054 0.060851628085856646 C11.205418826624054 0.060851628085856646 9.938719307092697 0.8748164965188607 9.938719307092697 0.8748164965188607 C9.938719307092697 0.8748164965188607 8.769458212140648 0.060851628085856646 8.769458212140648 0.060851628085856646 C8.477142938402721 -0.04089398046824044 8.184827664664681 -0.04089398046824044 8.087389240085372 0.2643428451941645 C7.89251239092664 0.4678340623023587 7.989950815506063 0.7730708879647636 8.184827664664681 0.9765621050729578 C8.184827664664681 0.9765621050729578 9.743842457934079 1.994018190614156 9.743842457934079 1.994018190614156 C9.841280882513388 2.095763799168253 9.938719307092697 2.095763799168253 10.03615773167212 2.095763799168253 C10.133596156251429 2.095763799168253 10.231034580830737 2.095763799168253 10.328473005410046 1.994018190614156 C10.328473005410046 1.994018190614156 11.887487798679444 0.9765621050729578 11.887487798679444 0.9765621050729578 C11.984926223258753 0.7730708879647636 12.082364647838176 0.4678340623023587 11.887487798679444 0.2643428451941645 Z" vector-effect="non-scaling-stroke"/></g><g><defs><path id="path-168354974462618" d="M4.1,0l-4.1,11h1.9l1.1,-3.2h3.9l1.1,3.2h2l-4,-11zM3.6,6.3l1.4,-4l1.4,3.9h-2.8z" vector-effect="non-scaling-stroke"/></defs><path style="stroke-width: 0; stroke-linecap: butt; stroke-linejoin: miter; fill: rgb(167, 167, 167);" d="M4.1,0l-4.1,11h1.9l1.1,-3.2h3.9l1.1,3.2h2l-4,-11zM3.6,6.3l1.4,-4l1.4,3.9h-2.8z" transform="translate(0, 3) rotate(0)" vector-effect="non-scaling-stroke"/></g></svg></button>
            <button id="larger"><svg height="15" overflow="visible" viewBox="0 0 16 15" width="16" xmlns="http://www.w3.org/2000/svg"><g><defs><path id="path-168354974462824" d="M15.697912710568632 2.300000000000025 C15.697912710568632 2.300000000000025 14.108250663928771 1.3000000000000143 14.108250663928771 1.3000000000000143 C14.00889678601378 1.200000000000013 13.90954290809879 1.200000000000013 13.810189030183796 1.200000000000013 C13.710835152268805 1.200000000000013 13.611481274353814 1.200000000000013 13.512127396438823 1.3000000000000143 C13.512127396438823 1.3000000000000143 11.92246534979896 2.300000000000025 11.92246534979896 2.300000000000025 C11.92246534979896 2.5000000000000275 11.82311147188397 2.800000000000031 11.92246534979896 3.0000000000000333 C12.121173105628943 3.2000000000000357 12.419234739373918 3.3000000000000362 12.6179424952039 3.2000000000000357 C12.6179424952039 3.2000000000000357 13.909542908098787 2.4000000000000266 13.909542908098787 2.4000000000000266 C13.909542908098787 2.4000000000000266 15.201143320993676 3.2000000000000357 15.201143320993676 3.2000000000000357 C15.399851076823659 3.3000000000000362 15.797266588483623 3.2000000000000357 15.896620466398614 3.0000000000000333 C16.095328222228595 2.800000000000031 15.995974344313607 2.5000000000000275 15.697912710568632 2.300000000000025 Z" vector-effect="non-scaling-stroke"/></defs> <path style="stroke-width: 0; stroke-linecap: butt; stroke-linejoin: miter; fill: rgb(167, 167, 167);" d="M15.697912710568517 2.299999999999841 C15.697912710568517 2.299999999999841 14.10825066392863 1.2999999999998408 14.10825066392863 1.2999999999998408 C14.008896786013679 1.199999999999818 13.909542908098729 1.199999999999818 13.810189030183665 1.199999999999818 C13.710835152268714 1.199999999999818 13.61148127435365 1.199999999999818 13.5121273964387 1.2999999999998408 C13.5121273964387 1.2999999999998408 11.922465349798813 2.299999999999841 11.922465349798813 2.299999999999841 C11.922465349798813 2.4999999999997726 11.823111471883863 2.799999999999841 11.922465349798813 2.9999999999997726 C12.121173105628827 3.199999999999818 12.419234739373792 3.299999999999841 12.617942495203806 3.199999999999818 C12.617942495203806 3.199999999999818 13.909542908098729 2.39999999999975 13.909542908098729 2.39999999999975 C13.909542908098729 2.39999999999975 15.201143320993538 3.199999999999818 15.201143320993538 3.199999999999818 C15.399851076823552 3.299999999999841 15.797266588483467 3.199999999999818 15.89662046639853 2.9999999999997726 C16.09532822222843 2.799999999999841 15.995974344313481 2.4999999999997726 15.697912710568517 2.299999999999841 Z" vector-effect="non-scaling-stroke"/></g><g><defs><path id="path-168354974462822" d="M5.72263,0l-5.72263,15h2.65693l1.63504,-4.3h5.41606l1.53285,4.3h2.75912l-5.62044,-15zM5.0073,8.5l1.94161,-5.4l1.94161,5.4z" vector-effect="non-scaling-stroke"/></defs><path style="stroke-width: 0; stroke-linecap: butt; stroke-linejoin: miter; fill: rgb(167, 167, 167);" d="M5.72263,0l-5.72263,15h2.65693l1.63504,-4.3h5.41606l1.53285,4.3h2.75912l-5.62044,-15zM5.0073,8.5l1.94161,-5.4l1.94161,5.4z" transform="translate(0, 0) rotate(0)" vector-effect="non-scaling-stroke"/></g></svg></button>
          </div>
        </div>
      </form>
    </div>
    """
  end

  defp format_time(hour, minute) do
    meridian = if hour < 12, do: "AM", else: "PM"
    hour = if hour in [0, 00], do: 12, else: hour
    hour = if hour > 12, do: hour |> rem(12), else: hour
    hour = if hour < 10, do: "0#{hour}", else: hour
    minute = if minute < 10, do: "0#{minute}", else: minute
    "#{hour}:#{minute} #{meridian}"
  end

  defp show_bubble(_, _, {{:typing, msg}, _}, _, _) do
    {:typing, msg}
  end

  defp show_bubble(_, _, {{:sent, msg, time_dtz, id, name, source_id, prev_message}, _}, _, _) do
    create_bubble(:sent, msg, time_dtz, id, name, source_id, prev_message, "", nil)
  end

  defp show_bubble(
         _,
         socket,
         {{:system, msg, time_dtz, id, name, source_id, prev_message}, _},
         _,
         configuration
       ) do
    create_bubble(
      :system,
      msg,
      time_dtz,
      id,
      name,
      source_id,
      prev_message,
      configuration,
      socket
    )
  end

  defp show_bubble(
         _,
         _,
         {{:received, msg, time_dtz, id, name, source_id, prev_message}, _},
         _,
         configuration
       ) do
    create_bubble(:received, msg, time_dtz, id, name, source_id, prev_message, configuration, nil)
  end

  defp get_hour_minute(time_dtz) when time_dtz in [nil, "", []] do
    [nil, nil]
  end

  defp get_hour_minute([hour, minute, _]) do
    [hour, minute]
  end

  defp create_bubble(
         type,
         msg,
         time_dtz,
         id,
         name,
         source_id,
         prev_message,
         configuration,
         socket
       ) do
    [hour, minute] = get_hour_minute(time_dtz)

    case type do
      :sent ->
        identity_text =
          get_identity_text(
            type,
            name,
            source_id,
            prev_message,
            hour,
            minute,
            configuration,
            socket
          )

        {:sent, ~s(<div id="msg-#{id}" class="sent">#{identity_text}#{msg}</div>)}

      :system ->
        identity_text =
          get_identity_text(
            type,
            name,
            source_id,
            prev_message,
            hour,
            minute,
            configuration,
            socket
          )

        {:received, ~s(<div id="msg-#{id}" class="received">#{identity_text}#{msg}</div>)}

      :received ->
        identity_text =
          get_identity_text(
            type,
            name,
            source_id,
            prev_message,
            hour,
            minute,
            configuration,
            socket
          )

        {:received, ~s[<div id="msg-#{id}" class="received">#{identity_text}#{msg}</div>]}
    end
  end

  defp get_identity_text(type, name, source_id, prev_message, hour, minute, configuration, socket) do
    case prev_message do
      {prev_source_id, [prev_hour, prev_minute, _]}
      when prev_source_id == source_id and prev_hour == hour and prev_minute == minute ->
        ""

      _ ->
        case type do
          :sent ->
            ~s(<p><b>#{name}:</b> #{format_time(hour, minute)}</p>)

          :system ->
            ~s(<div class="avatar-text-wrapper"><div class="system-avatar-container" style="background-color: #{configuration |> Map.get("transcript") |> Map.get("systemAvatar")}"><img src=#{Routes.static_path(socket, "/svg/contact-point-icon.svg")} /></div><p><b>#{name}:</b> #{format_time(hour, minute)}</p></div>)

          :received ->
            ~s[<div class="avatar-text-wrapper"><svg version="1.2" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" overflow="visible" preserveAspectRatio="none" viewBox="0 0 40 40" x="0px" y="0px" width="32" height="32" xml:space="preserve"><g transform="translate(1, 1)"><path fill="#{configuration |> Map.get("transcript") |> Map.get("agentAvatar")}" d="M18.854-0.024c-10.477,0-19,8.522-19,18.999c0,5.427,2.299,10.316,5.959,13.782  c3.406,3.226,7.99,5.219,13.041,5.219c5.077,0,9.685-2.014,13.097-5.27c3.628-3.462,5.903-8.331,5.903-13.731  C37.854,8.498,29.33-0.024,18.854-0.024z M30.401,31.391c-0.747-0.571-1.456-1.021-2.021-1.263  c-1.665-0.716-3.694-2.526-4.635-3.424c-0.323-0.305-0.55-0.622-0.553-1.392c-0.001-0.899,0.019-0.553,0.162-1.494l-0.013,0.002  c0.673-0.662,0.909-2.332,1.523-2.938c0.877-0.853,1.822-1.904,2.092-3.218c0.359-1.743-0.37-1.965-0.37-2.569  c0-1.259-0.013-3.333-0.408-4.681c-0.02-1.776-0.312-2.548-0.925-3.215c-0.574-0.624-1.993-0.477-2.735-0.887  c-1.146-0.635-2.089-0.877-3.288-0.908V5.399c-0.036,0-0.072,0.002-0.106,0.002c-0.057,0-0.114-0.002-0.179-0.002l0.005,0.011  c-2.927,0.109-6.042,1.955-7.11,4.92c-0.396,1.106-0.248,3.507-0.248,4.766c0,0.603-0.729,0.826-0.369,2.569  c0.271,1.313,1.215,2.363,2.091,3.216c0.616,0.604,0.852,2.277,1.523,2.938c0.148,0.974,0.165,0.695,0.156,1.584  c0,0.302,0.013,0.77-0.472,1.23c-0.906,0.873-2.997,2.761-4.713,3.495c-0.629,0.27-1.476,0.765-2.369,1.385  c-3.412-3.107-5.568-7.569-5.568-12.538c0-9.363,7.618-16.98,16.981-16.98s16.981,7.617,16.981,16.98  C35.835,23.877,33.734,28.288,30.401,31.391z" vector-effect="non-scaling-stroke" /></g></svg><p><b>#{name}:</b> #{format_time(hour, minute)}</p></div>]
        end
    end
  end
end
